//
//  MCPConfig.swift
//  WXL
//
//  MCP configuration and utilities for Claude Code compatibility
//

import Foundation

/// MCP Configuration
struct MCPConfig {
    var port: UInt16 = 9527
    var enabled: Bool = true
    var maxConnections: Int = 5
    var host: String = "127.0.0.1"  // localhost only for security

    /// HTTP endpoint for MCP JSON-RPC
    var mcpEndpoint: String {
        return "http://\(host):\(port)/mcp"
    }

    /// Health check endpoint
    var healthEndpoint: String {
        return "http://\(host):\(port)/health"
    }

    static let `default` = MCPConfig()

    static func load() -> MCPConfig {
        var config = MCPConfig()

        if let port = UserDefaults.standard.object(forKey: "mcpPort") as? UInt16 {
            config.port = port
        } else if let portInt = UserDefaults.standard.object(forKey: "mcpPort") as? Int,
                  let port = UInt16(exactly: portInt) {
            config.port = port
        }

        if let enabled = UserDefaults.standard.object(forKey: "mcpEnabled") as? Bool {
            config.enabled = enabled
        }

        if let host = UserDefaults.standard.string(forKey: "mcpHost") {
            config.host = host
        }

        return config
    }

    func save() {
        UserDefaults.standard.set(port, forKey: "mcpPort")
        UserDefaults.standard.set(enabled, forKey: "mcpEnabled")
        UserDefaults.standard.set(host, forKey: "mcpHost")
    }
}

/// MCP Client Info
struct MCPClientInfo: Codable {
    let name: String
    let version: String
}

/// MCP Server Status
enum MCPServerStatus {
    case stopped
    case starting
    case running
    case error(String)

    var description: String {
        let config = MCPConfig.load()
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Running on \(config.mcpEndpoint)"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Claude Code Configuration Helper

extension MCPConfig {
    /// Generates the Claude Code MCP configuration snippet
    /// User can add this to their Claude Code settings
    var claudeCodeConfig: String {
        return """
        {
          "mcpServers": {
            "wxl": {
              "type": "http",
              "url": "\(mcpEndpoint)"
            }
          }
        }
        """
    }

    /// Instructions for configuring Claude Code
    static var claudeCodeSetupInstructions: String {
        return """
        # WXL MCP Server - Claude Code 配置说明

        ## 1. 确保 WXL 应用正在运行
        MCP 服务器会在应用启动时自动启动在 http://127.0.0.1:9527

        ## 2. 在 Claude Code 中添加 MCP 服务器

        运行以下命令:

        ```bash
        claude mcp add --transport http wxl http://127.0.0.1:9527/mcp
        ```

        ## 3. 验证连接

        在 Claude Code 中运行 `/mcp` 查看服务器状态

        ## 可用的工具

        - `get_clipboard_history` - 获取剪贴板历史记录
        - `search_clipboard` - 搜索剪贴板内容
        - `generate_note` - 从剪贴板项目生成笔记

        ## 可用的资源

        - `wxl://clipboard/history` - 剪贴板历史
        - `wxl://clipboard/pinned` - 固定的剪贴板项目
        """
    }
}
