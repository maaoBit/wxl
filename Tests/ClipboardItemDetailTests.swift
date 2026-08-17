//
//  ClipboardItemDetailTests.swift
//  WXLTests
//
//  Unit tests for detail panel display logic (detailLines / footerStatText)
//

import XCTest
@testable import WXL

final class ClipboardItemDetailTests: XCTestCase {

    // MARK: - detailLines

    func testDetailLines_FileItem_SingleFile_ReturnsFullPath() {
        let item = ClipboardItem(
            content: "folder",
            contentType: .filePath,
            fileURLs: ["/Users/maao/Documents/folder"]
        )

        XCTAssertEqual(item.detailLines, ["/Users/maao/Documents/folder"])
    }

    func testDetailLines_FileItem_MultipleFiles_ReturnsAllPaths() {
        let item = ClipboardItem(
            content: "3 个文件",
            contentType: .filePath,
            fileURLs: ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"]
        )

        XCTAssertEqual(item.detailLines, ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"])
    }

    func testDetailLines_FileItem_EmptyFileURLs_FallsBackToContent() {
        let item = ClipboardItem(content: "folder", contentType: .filePath, fileURLs: [])

        XCTAssertEqual(item.detailLines, ["folder"])
    }

    func testDetailLines_FileItem_NilFileURLs_FallsBackToContent() {
        let item = ClipboardItem(content: "/Users/maao/some/path", contentType: .filePath, fileURLs: nil)

        XCTAssertEqual(item.detailLines, ["/Users/maao/some/path"])
    }

    func testDetailLines_TextItem_ReturnsWholeContentAsSingleElement() {
        let item = ClipboardItem(content: "line 1\nline 2\nline 3")

        XCTAssertEqual(item.detailLines, ["line 1\nline 2\nline 3"])
    }

    func testDetailLines_ImageItem_ReturnsContent() {
        let item = ClipboardItem(content: "[Image]", contentType: .image)

        XCTAssertEqual(item.detailLines, ["[Image]"])
    }

    // MARK: - footerStatText

    func testFooterStatText_FileItem_ShowsFileCount() {
        let item = ClipboardItem(
            content: "3 个文件",
            contentType: .filePath,
            fileURLs: ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"]
        )

        XCTAssertEqual(item.footerStatText, "3 个文件")
    }

    func testFooterStatText_FileItem_SingleFile_ShowsOneFile() {
        let item = ClipboardItem(
            content: "folder",
            contentType: .filePath,
            fileURLs: ["/Users/maao/Documents/folder"]
        )

        XCTAssertEqual(item.footerStatText, "1 个文件")
    }

    func testFooterStatText_FileItem_NilFileURLs_ShowsCharCount() {
        let item = ClipboardItem(content: "/Users/maao/some/path", contentType: .filePath, fileURLs: nil)

        XCTAssertEqual(item.footerStatText, "\(item.content.count) 字符")
    }

    func testFooterStatText_TextItem_ShowsCharCount() {
        let item = ClipboardItem(content: "hello 世界")

        XCTAssertEqual(item.footerStatText, "8 字符")
    }
}
