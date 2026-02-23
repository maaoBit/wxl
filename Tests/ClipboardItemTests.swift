//
//  ClipboardItemTests.swift
//  WXLTests
//
//  Unit tests for ClipboardItem model and content type detection
//

import XCTest
@testable import WXL

final class ClipboardItemTests: XCTestCase {

    // MARK: - Content Type Detection Tests

    // MARK: URL Detection

    func testDetectContentType_HTTP_URL() {
        let content = "http://example.com"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .url)
    }

    func testDetectContentType_HTTPS_URL() {
        let content = "https://example.com/path?query=value"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .url)
    }

    func testDetectContentType_FTP_URL() {
        let content = "ftp://ftp.example.com/files"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .url)
    }

    func testDetectContentType_URL_WithPort() {
        let content = "https://example.com:8080/path"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .url)
    }

    func testDetectContentType_URL_WithSubdomain() {
        let content = "https://sub.domain.example.com"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .url)
    }

    func testDetectContentType_URL_WithAnchor() {
        let content = "https://example.com/page#section"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .url)
    }

    func testDetectContentType_URL_WithChinese() {
        let content = "https://example.com/中文路径"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .url)
    }

    // MARK: Email Detection

    func testDetectContentType_Email_Simple() {
        let content = "test@example.com"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .email)
    }

    func testDetectContentType_Email_WithDots() {
        let content = "user.name@subdomain.example.com"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .email)
    }

    func testDetectContentType_Email_WithPlus() {
        let content = "user+tag@example.com"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .email)
    }

    func testDetectContentType_Email_WithNumbers() {
        let content = "user123@example123.com"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .email)
    }

    func testDetectContentType_Email_WithUnderscore() {
        let content = "user_name@example.com"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .email)
    }

    // MARK: Phone Number Detection

    func testDetectContentType_Phone_Simple() {
        let content = "13812345678"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .phoneNumber)
    }

    func testDetectContentType_Phone_WithSpaces() {
        let content = "138 1234 5678"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .phoneNumber)
    }

    func testDetectContentType_Phone_WithDashes() {
        let content = "138-1234-5678"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .phoneNumber)
    }

    func testDetectContentType_Phone_WithCountryCode() {
        let content = "+86 138 1234 5678"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .phoneNumber)
    }

    func testDetectContentType_Phone_WithParentheses() {
        let content = "(010) 1234-5678"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .phoneNumber)
    }

    func testDetectContentType_Phone_International() {
        let content = "+1 (555) 123-4567"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .phoneNumber)
    }

    // MARK: File Path Detection

    func testDetectContentType_FilePath_Absolute() {
        let content = "/Users/username/Documents/file.txt"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .filePath)
    }

    func testDetectContentType_FilePath_HomeDirectory() {
        let content = "~/Documents/file.txt"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .filePath)
    }

    func testDetectContentType_FilePath_Root() {
        let content = "/etc/hosts"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .filePath)
    }

    func testDetectContentType_FilePath_WithSpaces() {
        let content = "/Users/username/My Documents/file name.txt"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .filePath)
    }

    // MARK: Code Detection

    func testDetectContentType_Code_Swift() {
        let content = "func myFunction() { return true }"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_Variable() {
        let content = "var myVariable = 42"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_Constant() {
        let content = "let myConstant = \"hello\""
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_Import() {
        let content = "import Foundation"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_C_Include() {
        let content = "#include <stdio.h>"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_Python_Def() {
        let content = "def my_function():"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_Python_Class() {
        let content = "class MyClass:"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_ArrowFunction() {
        let content = "const fn = () => { return 1 }"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_SwiftArrow() {
        let content = "let result = input -> output"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    func testDetectContentType_Code_Braces() {
        let content = "{ \"key\": \"value\" }"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .code)
    }

    // MARK: Text Detection (Default)

    func testDetectContentType_PlainText() {
        let content = "This is plain text"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .text)
    }

    func testDetectContentType_ChineseText() {
        let content = "这是一段中文文本"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .text)
    }

    func testDetectContentType_MixedLanguageText() {
        let content = "Hello 世界! This is 测试 text."
        XCTAssertEqual(ClipboardItem.detectContentType(content), .text)
    }

    func testDetectContentType_NumberText() {
        let content = "12345"
        XCTAssertEqual(ClipboardItem.detectContentType(content), .text)
    }

    func testDetectContentType_EmptyString() {
        let content = ""
        XCTAssertEqual(ClipboardItem.detectContentType(content), .text)
    }

    func testDetectContentType_Whitespace() {
        let content = "   \n\t  "
        XCTAssertEqual(ClipboardItem.detectContentType(content), .text)
    }

    // MARK: - Preview Text Tests

    func testPreviewText_ShortContent() {
        let item = ClipboardItem(content: "Short text")
        XCTAssertEqual(item.previewText, "Short text")
    }

    func testPreviewText_LongContent() {
        let longContent = String(repeating: "a", count: 150)
        let item = ClipboardItem(content: longContent)
        XCTAssertEqual(item.previewText.count, 103) // 100 chars + "..."
        XCTAssertTrue(item.previewText.hasSuffix("..."))
    }

    func testPreviewText_Exactly100Chars() {
        let content = String(repeating: "a", count: 100)
        let item = ClipboardItem(content: content)
        XCTAssertEqual(item.previewText, content)
        XCTAssertFalse(item.previewText.hasSuffix("..."))
    }

    // MARK: - ClipboardItem Initialization Tests

    func testInit_DefaultValues() {
        let item = ClipboardItem(content: "Test content")

        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.content, "Test content")
        XCTAssertEqual(item.contentType, .text)
        XCTAssertNil(item.sourceApp)
        XCTAssertNil(item.sourceAppBundle)
        XCTAssertNotNil(item.createdAt)
        XCTAssertFalse(item.isPinned)
        XCTAssertNotNil(item.expiresAt)
        XCTAssertNil(item.imageData)
        XCTAssertNil(item.ocrText)
    }

    func testInit_WithContentType() {
        let item = ClipboardItem(content: "https://example.com", contentType: .url)
        XCTAssertEqual(item.contentType, .url)
    }

    func testInit_WithSourceApp() {
        let item = ClipboardItem(content: "Test", sourceApp: "Safari", sourceAppBundle: "com.apple.Safari")
        XCTAssertEqual(item.sourceApp, "Safari")
        XCTAssertEqual(item.sourceAppBundle, "com.apple.Safari")
    }

    func testInit_FromDatabase() {
        let id = UUID()
        let createdAt = Date()
        let expiresAt = Date().addingTimeInterval(3600)
        let imageData = "test".data(using: .utf8)

        let item = ClipboardItem(
            id: id,
            content: "Test content",
            contentType: .code,
            sourceApp: "Xcode",
            sourceAppBundle: "com.apple.dt.Xcode",
            createdAt: createdAt,
            isPinned: true,
            expiresAt: expiresAt,
            imageData: imageData,
            ocrText: "OCR text"
        )

        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.content, "Test content")
        XCTAssertEqual(item.contentType, .code)
        XCTAssertEqual(item.sourceApp, "Xcode")
        XCTAssertEqual(item.sourceAppBundle, "com.apple.dt.Xcode")
        XCTAssertEqual(item.createdAt, createdAt)
        XCTAssertTrue(item.isPinned)
        XCTAssertEqual(item.expiresAt, expiresAt)
        XCTAssertEqual(item.imageData, imageData)
        XCTAssertEqual(item.ocrText, "OCR text")
    }

    // MARK: - ContentType Tests

    func testContentType_AllCases() {
        let allCases = ContentType.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.text))
        XCTAssertTrue(allCases.contains(.url))
        XCTAssertTrue(allCases.contains(.filePath))
        XCTAssertTrue(allCases.contains(.email))
        XCTAssertTrue(allCases.contains(.phoneNumber))
        XCTAssertTrue(allCases.contains(.image))
        XCTAssertTrue(allCases.contains(.code))
    }

    func testContentType_RawValue() {
        XCTAssertEqual(ContentType.text.rawValue, "text")
        XCTAssertEqual(ContentType.url.rawValue, "url")
        XCTAssertEqual(ContentType.filePath.rawValue, "filePath")
        XCTAssertEqual(ContentType.email.rawValue, "email")
        XCTAssertEqual(ContentType.phoneNumber.rawValue, "phoneNumber")
        XCTAssertEqual(ContentType.image.rawValue, "image")
        XCTAssertEqual(ContentType.code.rawValue, "code")
    }

    func testContentType_FromRawValue() {
        XCTAssertEqual(ContentType(rawValue: "text"), .text)
        XCTAssertEqual(ContentType(rawValue: "url"), .url)
        XCTAssertEqual(ContentType(rawValue: "invalid"), nil)
    }

    // MARK: - Array Extension Tests

    func testArraySafeSubscript_ValidIndex() {
        let array = [1, 2, 3]
        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 1], 2)
        XCTAssertEqual(array[safe: 2], 3)
    }

    func testArraySafeSubscript_InvalidIndex() {
        let array = [1, 2, 3]
        XCTAssertNil(array[safe: -1])
        XCTAssertNil(array[safe: 3])
        XCTAssertNil(array[safe: 100])
    }

    func testArraySafeMethod_ValidIndex() {
        let array = ["a", "b", "c"]
        XCTAssertEqual(array.safe(at: 0), "a")
        XCTAssertEqual(array.safe(at: 2), "c")
    }

    func testArraySafeMethod_InvalidIndex() {
        let array = ["a", "b", "c"]
        XCTAssertNil(array.safe(at: -1))
        XCTAssertNil(array.safe(at: 3))
    }

    func testArraySafeMethod_EmptyArray() {
        let array: [Int] = []
        XCTAssertNil(array.safe(at: 0))
    }
}
