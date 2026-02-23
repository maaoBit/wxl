//
//  ClipboardItemCodableTests.swift
//  WXLTests
//
//  Unit tests for ClipboardItem Codable functionality
//

import XCTest
@testable import WXL

final class ClipboardItemCodableTests: XCTestCase {

    // MARK: - Encoding Tests

    func testEncode_TextItem() throws {
        let item = ClipboardItem(content: "Hello World")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(item)
        XCTAssertGreaterThan(data.count, 0)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json)
        XCTAssertEqual(json?["content"] as? String, "Hello World")
        XCTAssertEqual(json?["contentType"] as? String, "text")
        XCTAssertFalse((json?["isPinned"] as? Bool) ?? true)
    }

    func testEncode_URLItem() throws {
        let item = ClipboardItem(content: "https://example.com", contentType: .url)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["contentType"] as? String, "url")
    }

    func testEncode_EmailItem() throws {
        let item = ClipboardItem(content: "test@example.com", contentType: .email)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["contentType"] as? String, "email")
    }

    func testEncode_WithSourceApp() throws {
        let item = ClipboardItem(
            content: "Test",
            sourceApp: "Safari",
            sourceAppBundle: "com.apple.Safari"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["sourceApp"] as? String, "Safari")
        XCTAssertEqual(json?["sourceAppBundle"] as? String, "com.apple.Safari")
    }

    func testEncode_WithImageData() throws {
        let imageData = "test image data".data(using: .utf8)!
        let item = ClipboardItem(content: "[Image]", contentType: .image, imageData: imageData)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["imageData"])
        XCTAssertEqual(json?["contentType"] as? String, "image")
    }

    func testEncode_AllContentTypes() throws {
        let encoder = JSONEncoder()

        for contentType in ContentType.allCases {
            let item = ClipboardItem(content: "test", contentType: contentType)
            let data = try encoder.encode(item)
            XCTAssertGreaterThan(data.count, 0, "Failed to encode \(contentType)")
        }
    }

    // MARK: - Decoding Tests

    func testDecode_TextItem() throws {
        let id = UUID()
        let json: [String: Any?] = [
            "id": id.uuidString,
            "content": "Test content",
            "contentType": "text",
            "sourceApp": nil,
            "sourceAppBundle": nil,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "isPinned": false,
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)),
            "imageData": nil,
            "ocrText": nil
        ]

        let data = try JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(item.content, "Test content")
        XCTAssertEqual(item.contentType, .text)
        XCTAssertFalse(item.isPinned)
    }

    func testDecode_URLItem() throws {
        let json: [String: Any?] = [
            "id": UUID().uuidString,
            "content": "https://example.com",
            "contentType": "url",
            "sourceApp": nil,
            "sourceAppBundle": nil,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "isPinned": false,
            "expiresAt": nil,
            "imageData": nil,
            "ocrText": nil
        ]

        let data = try JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = try decoder.decode(ClipboardItem.self, from: data)
        XCTAssertEqual(item.contentType, .url)
    }

    func testDecode_AllContentTypes() throws {
        let contentTypes = ["text", "url", "filePath", "email", "phoneNumber", "image", "code"]

        for typeString in contentTypes {
            let json: [String: Any?] = [
                "id": UUID().uuidString,
                "content": "test",
                "contentType": typeString,
                "sourceApp": nil,
                "sourceAppBundle": nil,
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "isPinned": false,
                "expiresAt": nil,
                "imageData": nil,
                "ocrText": nil
            ]

            let data = try JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let item = try decoder.decode(ClipboardItem.self, from: data)
            XCTAssertEqual(item.contentType.rawValue, typeString)
        }
    }

    // MARK: - Round-trip Tests

    func testRoundTrip_SimpleItem() throws {
        let original = ClipboardItem(content: "Round trip test")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.content, decoded.content)
        XCTAssertEqual(original.contentType, decoded.contentType)
        XCTAssertEqual(original.isPinned, decoded.isPinned)
    }

    func testRoundTrip_CompleteItem() throws {
        let id = UUID()
        let createdAt = Date()
        let expiresAt = Date().addingTimeInterval(86400)
        let imageData = "image data".data(using: .utf8)

        let original = ClipboardItem(
            id: id,
            content: "Complete item test",
            contentType: .code,
            sourceApp: "Xcode",
            sourceAppBundle: "com.apple.dt.Xcode",
            createdAt: createdAt,
            isPinned: true,
            expiresAt: expiresAt,
            imageData: imageData,
            ocrText: "OCR recognized text"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.content, decoded.content)
        XCTAssertEqual(original.contentType, decoded.contentType)
        XCTAssertEqual(original.sourceApp, decoded.sourceApp)
        XCTAssertEqual(original.sourceAppBundle, decoded.sourceAppBundle)
        XCTAssertEqual(original.isPinned, decoded.isPinned)
        XCTAssertEqual(original.imageData, decoded.imageData)
        XCTAssertEqual(original.ocrText, decoded.ocrText)
    }

    func testRoundTrip_AllContentTypes() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for contentType in ContentType.allCases {
            let original = ClipboardItem(content: "test \(contentType.rawValue)", contentType: contentType)
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ClipboardItem.self, from: data)

            XCTAssertEqual(original.contentType, decoded.contentType, "Failed for \(contentType)")
        }
    }

    // MARK: - Edge Cases

    func testEncode_EmptyContent() throws {
        let item = ClipboardItem(content: "")

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded.content, "")
    }

    func testEncode_SpecialCharacters() throws {
        let specialContent = "Hello\"World\\Test\nNew\tTab"
        let item = ClipboardItem(content: specialContent)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded.content, specialContent)
    }

    func testEncode_UnicodeContent() throws {
        let unicodeContent = "你好世界 🌍 مرحبا Привет"
        let item = ClipboardItem(content: unicodeContent)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded.content, unicodeContent)
    }

    func testEncode_VeryLongContent() throws {
        let longContent = String(repeating: "a", count: 10000)
        let item = ClipboardItem(content: longContent)

        let encoder = JSONEncoder()
        let data = try encoder.encode(item)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClipboardItem.self, from: data)

        XCTAssertEqual(decoded.content.count, 10000)
    }

    func testDecode_InvalidContentType_ThrowsError() throws {
        let json: [String: Any?] = [
            "id": UUID().uuidString,
            "content": "test",
            "contentType": "invalidType",
            "sourceApp": nil,
            "sourceAppBundle": nil,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "isPinned": false,
            "expiresAt": nil,
            "imageData": nil,
            "ocrText": nil
        ]

        let data = try JSONSerialization.data(withJSONObject: json.compactMapValues { $0 })
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        XCTAssertThrowsError(try decoder.decode(ClipboardItem.self, from: data))
    }

    func testDecode_MissingRequiredField_ThrowsError() throws {
        let json: [String: Any] = [
            "id": UUID().uuidString,
            // missing content
            "contentType": "text",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "isPinned": false
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        XCTAssertThrowsError(try decoder.decode(ClipboardItem.self, from: data))
    }
}
