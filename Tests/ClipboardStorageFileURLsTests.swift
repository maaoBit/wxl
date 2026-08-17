//
//  ClipboardStorageFileURLsTests.swift
//  WXLTests
//
//  Unit tests for fileURLs persistence round-trips
//

import XCTest
@testable import WXL

final class ClipboardStorageFileURLsTests: XCTestCase {

    var storage: ClipboardStorage!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_\(UUID().uuidString).db").path
        storage = ClipboardStorage(databasePath: tempDBPath)
    }

    override func tearDown() {
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        storage = nil
        tempDBPath = nil
        super.tearDown()
    }

    // MARK: - Save / Load Round-trips

    func testFileURLs_SinglePath_RoundTrip() {
        let item = ClipboardItem(
            content: "folder",
            contentType: .filePath,
            fileURLs: ["/Users/maao/Documents/folder"]
        )

        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.contentType, .filePath)
        XCTAssertEqual(items.first?.fileURLs, ["/Users/maao/Documents/folder"])
    }

    func testFileURLs_MultiplePaths_RoundTrip() {
        let paths = ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"]
        let item = ClipboardItem(content: "3 个文件", contentType: .filePath, fileURLs: paths)

        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.first?.fileURLs, paths)
    }

    func testFileURLs_PathsWithSpacesAndChinese_RoundTrip() {
        let paths = ["/Users/maao/文档/我的 项目/文件 名.txt", "/tmp/another dir/空 格.txt"]
        let item = ClipboardItem(content: "2 个文件", contentType: .filePath, fileURLs: paths)

        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.first?.fileURLs, paths)
    }

    func testFileURLs_NilFileURLs_StaysNil() {
        let item = ClipboardItem(content: "/Users/maao/some/path", contentType: .filePath, fileURLs: nil)

        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.first?.fileURLs, nil)
    }

    // MARK: - Light Loading（面板实际使用的读取路径）

    func testFileURLs_LoadAllLight_PreservesPaths() {
        let item = ClipboardItem(
            content: "folder",
            contentType: .filePath,
            fileURLs: ["/Users/maao/Documents/folder"]
        )

        storage.save(item)

        let items = storage.loadAllLight()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.fileURLs, ["/Users/maao/Documents/folder"])
    }

    func testFileURLs_SearchLight_PreservesPaths() {
        let item = ClipboardItem(content: "uniqueFolderName", contentType: .filePath, fileURLs: ["/tmp/uniqueFolderName"])

        storage.save(item)

        let items = storage.searchLight(query: "uniqueFolderName")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.fileURLs, ["/tmp/uniqueFolderName"])
    }

    // MARK: - Dedup Update

    func testFileURLs_DuplicateContent_UpdatesPaths() {
        // 同名文件夹从不同位置复制：content 相同触发去重更新，fileURLs 应被新路径覆盖
        let first = ClipboardItem(content: "folder", contentType: .filePath, fileURLs: ["/old/location/folder"])
        storage.save(first)

        let second = ClipboardItem(content: "folder", contentType: .filePath, fileURLs: ["/new/location/folder"])
        let insertResult = storage.save(second)

        XCTAssertFalse(insertResult, "重复内容应走更新而非插入")
        let items = storage.loadAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.fileURLs, ["/new/location/folder"])
    }
}
