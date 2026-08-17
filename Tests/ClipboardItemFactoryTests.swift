//
//  ClipboardItemFactoryTests.swift
//  WXLTests
//
//  Unit tests for clipboard capture logic (ClipboardItemFactory)
//

import XCTest
import AppKit
@testable import WXL

/// ClipboardItemFactory 使用的剪贴板读取 mock
final class MockPasteboard: PasteboardReading {
    var propertyLists: [String: Any] = [:]
    var datas: [String: Data] = [:]
    var strings: [String: String] = [:]

    func propertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        return propertyLists[type.rawValue]
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        return datas[type.rawValue]
    }

    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        return strings[type.rawValue]
    }
}

final class ClipboardItemFactoryTests: XCTestCase {

    var tempFiles: [String] = []

    override func tearDown() {
        for path in tempFiles {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempFiles.removeAll()
        super.tearDown()
    }

    /// 创建一个真实存在的临时文件，返回其路径
    private func makeTempFile(_ name: String) -> String {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("wxl_test_\(UUID().uuidString)_\(name)").path
        FileManager.default.createFile(atPath: path, contents: Data([0x00]))
        tempFiles.append(path)
        return path
    }

    // MARK: - File Detection (NSFilenamesPboardType)

    func testMakeItem_SingleExistingFile() {
        let path = makeTempFile("report.pdf")
        let pasteboard = MockPasteboard()
        pasteboard.propertyLists["NSFilenamesPboardType"] = [path]

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .filePath)
        XCTAssertEqual(item?.content, (path as NSString).lastPathComponent)
        XCTAssertEqual(item?.fileURLs, [path])
    }

    func testMakeItem_MultipleExistingFiles() {
        let pathA = makeTempFile("a.txt")
        let pathB = makeTempFile("b.txt")
        let pasteboard = MockPasteboard()
        pasteboard.propertyLists["NSFilenamesPboardType"] = [pathA, pathB]

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .filePath)
        XCTAssertEqual(item?.content, "2 个文件")
        XCTAssertEqual(item?.fileURLs, [pathA, pathB])
    }

    func testMakeItem_NonexistentFiles_FilteredOut() {
        let existing = makeTempFile("exists.txt")
        let pasteboard = MockPasteboard()
        pasteboard.propertyLists["NSFilenamesPboardType"] = [existing, "/nonexistent/gone.txt"]

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.fileURLs, [existing])
        XCTAssertEqual(item?.content, (existing as NSString).lastPathComponent)
    }

    func testMakeItem_AllFilesNonexistent_FallsThrough() {
        let pasteboard = MockPasteboard()
        pasteboard.propertyLists["NSFilenamesPboardType"] = ["/nonexistent/gone.txt"]

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertNil(item)
    }

    // MARK: - File Detection (single fileURL flavor)

    func testMakeItem_SingleFileURL_NoText() {
        let path = makeTempFile("photo.png")
        let pasteboard = MockPasteboard()
        pasteboard.datas[NSPasteboard.PasteboardType.fileURL.rawValue] = Data("file://\(path)".utf8)

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .filePath)
        XCTAssertEqual(item?.content, (path as NSString).lastPathComponent)
        // 存纯路径，而不是 file:// URL
        XCTAssertEqual(item?.fileURLs, [path])
    }

    func testMakeItem_FileURL_WithTextContent_TextWins() {
        // 复制文件后又复制了同名文本等场景：有文本时不视为文件复制
        let path = makeTempFile("notes.txt")
        let pasteboard = MockPasteboard()
        pasteboard.datas[NSPasteboard.PasteboardType.fileURL.rawValue] = Data("file://\(path)".utf8)
        pasteboard.strings[NSPasteboard.PasteboardType.string.rawValue] = "some text"

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .text)
        XCTAssertEqual(item?.content, "some text")
        XCTAssertNil(item?.fileURLs)
    }

    func testMakeItem_FileURL_NonexistentFile_FallsThrough() {
        let pasteboard = MockPasteboard()
        pasteboard.datas[NSPasteboard.PasteboardType.fileURL.rawValue] = Data("file:///nonexistent/gone.txt".utf8)

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertNil(item)
    }

    // MARK: - Priority

    func testMakeItem_FileNamesAndImageBothPresent_FileWins() {
        let path = makeTempFile("pic.png")
        let pasteboard = MockPasteboard()
        pasteboard.propertyLists["NSFilenamesPboardType"] = [path]
        pasteboard.datas[NSPasteboard.PasteboardType.png.rawValue] = Data([0x89, 0x50])

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .filePath)
        XCTAssertEqual(item?.fileURLs, [path])
    }

    // MARK: - Image Detection

    func testMakeItem_ImageData() {
        let pasteboard = MockPasteboard()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        pasteboard.datas[NSPasteboard.PasteboardType.png.rawValue] = imageData

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .image)
        XCTAssertEqual(item?.content, "[Image]")
        XCTAssertEqual(item?.imageData, imageData)
    }

    // MARK: - Text Detection

    func testMakeItem_Text_DetectsURLType() {
        let pasteboard = MockPasteboard()
        pasteboard.strings[NSPasteboard.PasteboardType.string.rawValue] = "https://example.com"

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .url)
        XCTAssertEqual(item?.content, "https://example.com")
    }

    func testMakeItem_PlainText() {
        let pasteboard = MockPasteboard()
        pasteboard.strings[NSPasteboard.PasteboardType.string.rawValue] = "普通文本"

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertEqual(item?.contentType, .text)
        XCTAssertEqual(item?.content, "普通文本")
    }

    // MARK: - Empty

    func testMakeItem_EmptyPasteboard_ReturnsNil() {
        let pasteboard = MockPasteboard()

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertNil(item)
    }

    func testMakeItem_EmptyText_ReturnsNil() {
        let pasteboard = MockPasteboard()
        pasteboard.strings[NSPasteboard.PasteboardType.string.rawValue] = ""

        let item = ClipboardItemFactory.makeItem(from: pasteboard)

        XCTAssertNil(item)
    }

    // MARK: - Source App

    func testMakeItem_CarriesSourceApp() {
        let pasteboard = MockPasteboard()
        pasteboard.strings[NSPasteboard.PasteboardType.string.rawValue] = "text"

        let item = ClipboardItemFactory.makeItem(from: pasteboard, sourceApp: "Finder", sourceAppBundle: "com.apple.finder")

        XCTAssertEqual(item?.sourceApp, "Finder")
        XCTAssertEqual(item?.sourceAppBundle, "com.apple.finder")
    }
}
