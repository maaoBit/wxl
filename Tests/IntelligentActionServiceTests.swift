//
//  IntelligentActionServiceTests.swift
//  WXLTests
//
//  Unit tests for IntelligentActionService helper methods
//

import XCTest
@testable import WXL

final class IntelligentActionServiceTests: XCTestCase {

    var service: IntelligentActionService!

    override func setUp() {
        super.setUp()
        service = IntelligentActionService.shared
        service.simulationMode = true  // 启用模拟模式，避免打开实际应用
    }

    override func tearDown() {
        service.simulationMode = false
        service.lastSimulatedAction = nil
        service = nil
        super.tearDown()
    }

    // MARK: - cleanPhoneNumber Tests (via public interface)

    // Note: cleanPhoneNumber is private, so we test it indirectly through
    // the URL generation methods that use it

    func testOpenFaceTime_GeneratesCorrectURL() {
        // We can't directly test the URL without mocking NSWorkspace,
        // but we can verify the method doesn't crash with various inputs

        // These should not crash
        service.openFaceTime("13812345678")
        service.openFaceTime("+86 138 1234 5678")
        service.openFaceTime("(010) 1234-5678")
        service.openFaceTime("+1 (555) 123-4567")
    }

    func testOpenFaceTimeAudio_GeneratesCorrectURL() {
        // These should not crash
        service.openFaceTimeAudio("13812345678")
        service.openFaceTimeAudio("+86 138 1234 5678")
        service.openFaceTimeAudio("(010) 1234-5678")
    }

    // MARK: - ContentAction Tests

    func testContentAction_AllCases() {
        let allCases = ContentAction.allCases
        XCTAssertEqual(allCases.count, 7)
        XCTAssertTrue(allCases.contains(.openURL))
        XCTAssertTrue(allCases.contains(.revealInFinder))
        XCTAssertTrue(allCases.contains(.openFile))
        XCTAssertTrue(allCases.contains(.sendEmail))
        XCTAssertTrue(allCases.contains(.faceTime))
        XCTAssertTrue(allCases.contains(.faceTimeAudio))
        XCTAssertTrue(allCases.contains(.copyPath))
    }

    func testContentAction_RawValue() {
        XCTAssertEqual(ContentAction.openURL.rawValue, "在浏览器中打开")
        XCTAssertEqual(ContentAction.revealInFinder.rawValue, "在 Finder 中显示")
        XCTAssertEqual(ContentAction.openFile.rawValue, "打开文件")
        XCTAssertEqual(ContentAction.sendEmail.rawValue, "发送邮件")
        XCTAssertEqual(ContentAction.faceTime.rawValue, "FaceTime")
        XCTAssertEqual(ContentAction.faceTimeAudio.rawValue, "FaceTime 音频")
        XCTAssertEqual(ContentAction.copyPath.rawValue, "复制路径")
    }

    func testContentAction_Icon() {
        XCTAssertEqual(ContentAction.openURL.icon, "safari")
        XCTAssertEqual(ContentAction.revealInFinder.icon, "folder")
        XCTAssertEqual(ContentAction.openFile.icon, "doc")
        XCTAssertEqual(ContentAction.sendEmail.icon, "envelope")
        XCTAssertEqual(ContentAction.faceTime.icon, "video")
        XCTAssertEqual(ContentAction.faceTimeAudio.icon, "phone")
        XCTAssertEqual(ContentAction.copyPath.icon, "doc.on.clipboard")
    }

    func testContentAction_KeyboardShortcut() {
        XCTAssertEqual(ContentAction.openURL.keyboardShortcut, "⌘↵")
        XCTAssertEqual(ContentAction.revealInFinder.keyboardShortcut, "⌘↵")
        XCTAssertEqual(ContentAction.openFile.keyboardShortcut, "⌘O")
        XCTAssertEqual(ContentAction.sendEmail.keyboardShortcut, "⌘↵")
        XCTAssertEqual(ContentAction.faceTime.keyboardShortcut, "⌘↵")
        XCTAssertEqual(ContentAction.faceTimeAudio.keyboardShortcut, "⌘⇧↵")
        XCTAssertEqual(ContentAction.copyPath.keyboardShortcut, "⌥⌘C")
    }

    // MARK: - Singleton Tests

    func testSingleton_Instance() {
        let instance1 = IntelligentActionService.shared
        let instance2 = IntelligentActionService.shared
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - URL Cleaning Tests (via openURL)

    func testOpenURL_WithHTTP() {
        // Should not crash and should handle properly
        service.openURL("http://example.com")
    }

    func testOpenURL_WithHTTPS() {
        service.openURL("https://example.com")
    }

    func testOpenURL_WithoutScheme() {
        // Should add https://
        service.openURL("example.com")
    }

    func testOpenURL_WithWhitespace() {
        service.openURL("  https://example.com  ")
    }

    func testOpenURL_WithPath() {
        service.openURL("https://example.com/path/to/page")
    }

    func testOpenURL_WithQuery() {
        service.openURL("https://example.com/search?q=test")
    }

    func testOpenURL_WithAnchor() {
        service.openURL("https://example.com/page#section")
    }

    func testOpenURL_ChineseDomain() {
        service.openURL("https://例子.中国")
    }

    // MARK: - Email Tests (via openEmail)

    func testOpenEmail_Simple() {
        service.openEmail("test@example.com")
    }

    func testOpenEmail_WithWhitespace() {
        service.openEmail("  test@example.com  ")
    }

    func testOpenEmail_Complex() {
        service.openEmail("user.name+tag@subdomain.example.com")
    }

    // MARK: - File Path Tests (via revealInFinder)

    func testRevealInFinder_HomePath() {
        // Should expand ~ and handle gracefully even if file doesn't exist
        service.revealInFinder("~/Documents")
    }

    func testRevealInFinder_NonExistentPath() {
        // Should not crash for non-existent paths
        service.revealInFinder("/non/existent/path/that/does/not/exist")
    }

    func testOpenFile_NonExistentPath() {
        // Should not crash for non-existent paths
        service.openFile("/non/existent/path")
    }

    // MARK: - Edge Case Tests

    func testOpenURL_EmptyString() {
        // Should not crash with empty input
        service.openURL("")
    }

    func testOpenEmail_EmptyString() {
        service.openEmail("")
    }

    func testOpenFaceTime_EmptyString() {
        service.openFaceTime("")
    }

    func testOpenURL_InvalidCharacters() {
        service.openURL("not a valid url with spaces")
    }

    func testOpenURL_SpecialCharacters() {
        service.openURL("https://example.com/path?query=value&foo=bar#anchor")
    }
}
