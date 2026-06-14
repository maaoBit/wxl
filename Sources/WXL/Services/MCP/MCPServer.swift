//
//  MCPServer.swift
//  WXL
//
//  Model Context Protocol server for external LLM integration
//  HTTP transport for Claude Code compatibility
//

import Foundation
import Network
import os.log

/// MCP Server for WXL Clipboard Manager
/// Allows external LLMs (like Claude) to read clipboard history and generate notes
/// Uses HTTP transport for Claude Code compatibility
class MCPServer {
    static let shared = MCPServer()

    private var listener: NWListener?
    private var config: MCPConfig = .load()
    private var connections: [NWConnection] = []
    private let connectionsLock = NSLock()

    private var port: NWEndpoint.Port {
        return NWEndpoint.Port(rawValue: config.port) ?? 9527
    }

    private init() {}

    // MARK: - Server Lifecycle

    func start() {
        if listener != nil {
            stop()
        }

        config = MCPConfig.load()

        guard config.enabled else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: parameters, on: port)

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    Logger.log("MCP Server started on port \(self?.port.rawValue ?? 9527)", category: .general)
                case .failed(let error):
                    Logger.error("MCP Server failed: \(error)", category: .general)
                default:
                    break
                }
            }

            listener?.start(queue: .main)
        } catch {
            Logger.error("Failed to start MCP server: \(error)", category: .general)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connectionsLock.lock()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        connectionsLock.unlock()
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - HTTP Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.connectionsLock.lock()
                self?.connections.append(connection)
                self?.connectionsLock.unlock()
                self?.receiveHTTPRequest(from: connection)
            case .failed:
                self?.connectionsLock.lock()
                self?.connections.removeAll { $0 === connection }
                self?.connectionsLock.unlock()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func receiveHTTPRequest(from connection: NWConnection) {
        // Receive HTTP request data
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, let requestString = String(data: data, encoding: .utf8) {
                self?.handleHTTPRequest(requestString, connection: connection)
            }
            if error == nil && !isComplete {
                // Continue receiving for keep-alive connections
            }
        }
    }

    // MARK: - HTTP Request Handling

    private func handleHTTPRequest(_ requestString: String, connection: NWConnection) {
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendHTTPError(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }

        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else {
            sendHTTPError(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }

        let method = String(requestParts[0])
        let path = String(requestParts[1])

        // Extract body from HTTP request
        let body = extractBody(from: requestString)

        // Route HTTP requests
        switch (method, path) {
        case ("POST", "/mcp"):
            // JSON-RPC over HTTP
            handleJSONRPC(body: body, connection: connection)
        case ("GET", "/health"):
            sendHTTPResponse(connection: connection, statusCode: 200, body: #"{"status":"ok"}"#)
        case ("GET", "/"):
            // Server info
            let info = """
            {
                "name": "WXL Clipboard MCP",
                "version": "1.3.1",
                "protocol": "MCP over HTTP",
                "endpoints": {
                    "mcp": "POST /mcp - JSON-RPC 2.0 endpoint",
                    "health": "GET /health - Health check"
                }
            }
            """
            sendHTTPResponse(connection: connection, statusCode: 200, body: info, contentType: "application/json")
        default:
            sendHTTPError(connection: connection, statusCode: 404, message: "Not Found")
        }
    }

    private func extractBody(from request: String) -> String {
        // Find the double CRLF that separates headers from body
        guard let bodyStart = request.range(of: "\r\n\r\n") else {
            return ""
        }
        return String(request[bodyStart.upperBound...])
    }

    // MARK: - JSON-RPC Handling

    private func handleJSONRPC(body: String, connection: NWConnection) {
        guard !body.isEmpty,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = json["method"] as? String else {
            sendJSONRPCError(connection: connection, code: -32700, message: "Parse error")
            return
        }

        let id = json["id"]
        let params = json["params"] as? [String: Any]

        // Route to appropriate handler
        switch method {
        case "initialize":
            handleInitialize(connection: connection, id: id)
        case "tools/list":
            handleToolsList(connection: connection, id: id)
        case "tools/call":
            handleToolCall(connection: connection, id: id, params: params)
        case "resources/list":
            handleResourcesList(connection: connection, id: id)
        case "resources/read":
            handleResourceRead(connection: connection, id: id, params: params)
        case "ping":
            handlePing(connection: connection, id: id)
        default:
            sendJSONRPCError(connection: connection, code: -32601, message: "Method not found", id: id)
        }
    }

    // MARK: - MCP Handlers

    private func handlePing(connection: NWConnection, id: Any?) {
        sendJSONRPCResponse(connection: connection, result: [:], id: id)
    }

    private func handleInitialize(connection: NWConnection, id: Any?) {
        let result: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": [
                "tools": ["listChanged": true],
                "resources": ["subscribe": false, "listChanged": true]
            ],
            "serverInfo": [
                "name": "WXL Clipboard MCP",
                "version": "1.3.1"
            ]
        ]
        sendJSONRPCResponse(connection: connection, result: result, id: id)
    }

    private func handleToolsList(connection: NWConnection, id: Any?) {
        let tools = [
            [
                "name": "get_clipboard_history",
                "description": "Get recent clipboard history items",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "limit": ["type": "integer", "description": "Maximum number of items to return", "default": 20],
                        "contentType": ["type": "string", "description": "Filter by content type", "enum": ["text", "url", "filePath", "email", "phoneNumber", "image", "code"]],
                        "search": ["type": "string", "description": "Search query"]
                    ]
                ]
            ],
            [
                "name": "search_clipboard",
                "description": "Search clipboard history",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "Search query"],
                        "sourceApp": ["type": "string", "description": "Filter by source application"]
                    ],
                    "required": ["query"]
                ]
            ],
            [
                "name": "generate_note",
                "description": "Generate a note from selected clipboard items",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "itemIds": ["type": "array", "items": ["type": "string"], "description": "List of clipboard item IDs to include"],
                        "title": ["type": "string", "description": "Optional title for the note"]
                    ],
                    "required": ["itemIds"]
                ]
            ]
        ]

        sendJSONRPCResponse(connection: connection, result: ["tools": tools], id: id)
    }

    private func handleToolCall(connection: NWConnection, id: Any?, params: [String: Any]?) {
        guard let params = params,
              let toolName = params["name"] as? String,
              let arguments = params["arguments"] as? [String: Any] else {
            sendJSONRPCError(connection: connection, code: -32602, message: "Invalid params", id: id)
            return
        }

        var result: [String: Any]?

        switch toolName {
        case "get_clipboard_history":
            result = getClipboardHistory(args: arguments)
        case "search_clipboard":
            result = searchClipboard(args: arguments)
        case "generate_note":
            result = generateNote(args: arguments)
        default:
            sendJSONRPCError(connection: connection, code: -32601, message: "Unknown tool", id: id)
            return
        }

        sendJSONRPCResponse(
            connection: connection,
            result: ["content": [["type": "text", "text": result?["text"] ?? ""]]],
            id: id
        )
    }

    private func handleResourcesList(connection: NWConnection, id: Any?) {
        let resources = [
            ["uri": "wxl://clipboard/history", "name": "Clipboard History", "mimeType": "application/json"],
            ["uri": "wxl://clipboard/pinned", "name": "Pinned Items", "mimeType": "application/json"]
        ]

        sendJSONRPCResponse(connection: connection, result: ["resources": resources], id: id)
    }

    private func handleResourceRead(connection: NWConnection, id: Any?, params: [String: Any]?) {
        guard let params = params,
              let uri = params["uri"] as? String else {
            sendJSONRPCError(connection: connection, code: -32602, message: "Invalid params", id: id)
            return
        }

        var content: String?

        switch uri {
        case "wxl://clipboard/history":
            let items = ClipboardStorage.shared.loadAllLight()
            content = encodeItemsAsJSON(items)
        case "wxl://clipboard/pinned":
            let items = ClipboardStorage.shared.loadAllLight().filter { $0.isPinned }
            content = encodeItemsAsJSON(items)
        default:
            sendJSONRPCError(connection: connection, code: -32602, message: "Unknown resource", id: id)
            return
        }

        sendJSONRPCResponse(
            connection: connection,
            result: ["contents": [["uri": uri, "mimeType": "application/json", "text": content ?? ""]]],
            id: id
        )
    }

    // MARK: - Tool Implementations

    private func getClipboardHistory(args: [String: Any]) -> [String: Any] {
        let limit = args["limit"] as? Int ?? 20
        let contentType = args["contentType"] as? String
        let search = args["search"] as? String

        var items = ClipboardStorage.shared.loadAllLight()

        // Filter by content type
        if let type = contentType, let ct = ContentType(rawValue: type) {
            items = items.filter { $0.contentType == ct }
        }

        // Filter by search
        if let query = search, !query.isEmpty {
            items = items.filter {
                $0.content.localizedCaseInsensitiveContains(query) ||
                ($0.ocrText?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }

        // Limit
        items = Array(items.prefix(limit))

        return ["text": encodeItemsAsJSON(items) ?? "[]"]
    }

    private func searchClipboard(args: [String: Any]) -> [String: Any] {
        guard let query = args["query"] as? String else {
            return ["text": "Error: query is required"]
        }

        let sourceApp = args["sourceApp"] as? String
        let limit = args["limit"] as? Int ?? 100
        let items = ClipboardStorage.shared.searchLight(query: query, sourceApp: sourceApp, limit: limit)

        return ["text": encodeItemsAsJSON(items) ?? "[]"]
    }

    private func generateNote(args: [String: Any]) -> [String: Any] {
        guard let itemIds = args["itemIds"] as? [String] else {
            return ["text": "Error: itemIds is required"]
        }

        let title = args["title"] as? String ?? "Clipboard Notes"

        // Get items by IDs
        let allItems = ClipboardStorage.shared.loadAllLight()
        let selectedItems = itemIds.compactMap { id -> ClipboardItem? in
            guard let uuid = UUID(uuidString: id) else { return nil }
            return allItems.first { $0.id == uuid }
        }

        // Generate markdown
        var markdown = "# \(title)\n\n"
        markdown += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        markdown += "---\n\n"

        for item in selectedItems {
            markdown += "## \(item.contentType.rawValue.uppercased())\n"
            markdown += "Source: \(item.sourceApp ?? "Unknown")\n"
            markdown += "Time: \(item.timeAgo)\n\n"
            markdown += "```\n\(item.content)\n```\n\n"
        }

        return ["text": markdown]
    }

    // MARK: - Helpers

    private func encodeItemsAsJSON(_ items: [ClipboardItem]) -> String? {
        let jsonData = items.map { item -> [String: Any] in
            return [
                "id": item.id.uuidString,
                "content": item.content,
                "contentType": item.contentType.rawValue,
                "sourceApp": item.sourceApp ?? "",
                "createdAt": ISO8601DateFormatter().string(from: item.createdAt),
                "isPinned": item.isPinned,
                "previewText": item.previewText,
                "ocrText": item.ocrText ?? ""
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - HTTP Response Helpers

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String = "application/json", headers: [String: String] = [:]) {
        var response = "HTTP/1.1 \(statusCode) \(httpStatusMessage(statusCode))\r\n"
        response += "Content-Type: \(contentType)\r\n"
        response += "Content-Length: \(body.utf8.count)\r\n"
        response += "Connection: close\r\n"
        response += "Access-Control-Allow-Origin: *\r\n"
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"
        response += body

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in })
    }

    private func sendHTTPError(connection: NWConnection, statusCode: Int, message: String) {
        let body = #"{"error":"\#(message)"}"#
        sendHTTPResponse(connection: connection, statusCode: statusCode, body: body)
    }

    private func sendJSONRPCResponse(connection: NWConnection, result: [String: Any], id: Any?) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id = id {
            response["id"] = id
        }

        guard let data = try? JSONSerialization.data(withJSONObject: response),
              let body = String(data: data, encoding: .utf8) else {
            sendHTTPError(connection: connection, statusCode: 500, message: "Internal Server Error")
            return
        }

        sendHTTPResponse(connection: connection, statusCode: 200, body: body)
    }

    private func sendJSONRPCError(connection: NWConnection, code: Int, message: String, id: Any? = nil) {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": message]
        ]
        if let id = id {
            response["id"] = id
        }

        guard let data = try? JSONSerialization.data(withJSONObject: response),
              let body = String(data: data, encoding: .utf8) else {
            sendHTTPError(connection: connection, statusCode: 500, message: "Internal Server Error")
            return
        }

        sendHTTPResponse(connection: connection, statusCode: 200, body: body)
    }

    private func httpStatusMessage(_ statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}
