//
//  ClipboardStorageTests.swift
//  WXLTests
//
//  Unit tests for ClipboardStorage database operations
//

import XCTest
@testable import WXL

final class ClipboardStorageTests: XCTestCase {

    var storage: ClipboardStorage!
    var tempDBPath: String!

    override func setUp() {
        super.setUp()

        // 创建临时数据库路径
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_\(UUID().uuidString).db").path

        // 使用临时路径初始化存储
        storage = ClipboardStorage(databasePath: tempDBPath)
    }

    override func tearDown() {
        // 清理临时数据库文件
        if let path = tempDBPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        storage = nil
        tempDBPath = nil
        super.tearDown()
    }

    // MARK: - Save Tests

    func testSave_SingleItem() {
        let item = ClipboardItem(content: "Test content")

        let result = storage.save(item)

        XCTAssertTrue(result)

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Test content")
    }

    func testSave_MultipleItems() {
        let item1 = ClipboardItem(content: "First item")
        let item2 = ClipboardItem(content: "Second item")
        let item3 = ClipboardItem(content: "Third item")

        storage.save(item1)
        storage.save(item2)
        storage.save(item3)

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 3)
    }

    func testSave_DuplicateContent_UpdatesExisting() {
        let content = "Same content"

        let item1 = ClipboardItem(content: content, sourceApp: "App1")
        storage.save(item1)

        // 等待一下确保第一个保存完成
        Thread.sleep(forTimeInterval: 0.1)

        let item2 = ClipboardItem(content: content, sourceApp: "App2")
        storage.save(item2)

        let items = storage.loadAll()
        // 相同内容应该只保留一条，但更新了 sourceApp
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.sourceApp, "App2")
    }

    func testSave_WithAllFields() {
        let imageData = "test image".data(using: .utf8)
        let item = ClipboardItem(
            content: "Test content",
            contentType: .code,
            sourceApp: "Xcode",
            sourceAppBundle: "com.apple.dt.Xcode",
            imageData: imageData
        )

        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 1)
        let savedItem = items.first!
        XCTAssertEqual(savedItem.content, "Test content")
        XCTAssertEqual(savedItem.contentType, .code)
        XCTAssertEqual(savedItem.sourceApp, "Xcode")
        XCTAssertEqual(savedItem.sourceAppBundle, "com.apple.dt.Xcode")
        XCTAssertEqual(savedItem.imageData, imageData)
    }

    func testSave_AllContentTypes() {
        for contentType in ContentType.allCases {
            let item = ClipboardItem(content: "test \(contentType.rawValue)", contentType: contentType)
            let result = storage.save(item)
            XCTAssertTrue(result, "Failed to save \(contentType)")
        }

        let items = storage.loadAll()
        XCTAssertEqual(items.count, ContentType.allCases.count)
    }

    // MARK: - Load Tests

    func testLoadAll_EmptyDatabase() {
        let items = storage.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testLoadAll_OrderedByPinnedAndDate() {
        // 创建几个项目
        let item1 = ClipboardItem(content: "Item 1")
        let item2 = ClipboardItem(content: "Item 2")
        let item3 = ClipboardItem(content: "Item 3")

        storage.save(item1)
        Thread.sleep(forTimeInterval: 0.1)
        storage.save(item2)
        Thread.sleep(forTimeInterval: 0.1)
        storage.save(item3)

        // 置顶第二个项目
        storage.togglePin(item2.id)

        let items = storage.loadAll()

        // 置顶的项目应该排在前面
        XCTAssertEqual(items.first?.content, "Item 2")
        XCTAssertTrue(items.first?.isPinned ?? false)
    }

    // MARK: - Delete Tests

    func testDelete_ExistingItem() {
        let item = ClipboardItem(content: "To be deleted")
        storage.save(item)

        var items = storage.loadAll()
        XCTAssertEqual(items.count, 1)

        storage.delete(item.id)

        items = storage.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testDelete_NonExistentItem() {
        // 删除不存在的项目不应该崩溃
        storage.delete(UUID())

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testDelete_MultipleItems() {
        let item1 = ClipboardItem(content: "Item 1")
        let item2 = ClipboardItem(content: "Item 2")
        let item3 = ClipboardItem(content: "Item 3")

        storage.save(item1)
        storage.save(item2)
        storage.save(item3)

        storage.delete(item1.id)
        storage.delete(item3.id)

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Item 2")
    }

    // MARK: - Toggle Pin Tests

    func testTogglePin_PinItem() {
        let item = ClipboardItem(content: "Test item")
        storage.save(item)

        storage.togglePin(item.id)

        let items = storage.loadAll()
        XCTAssertTrue(items.first?.isPinned ?? false)
    }

    func testTogglePin_UnpinItem() {
        let item = ClipboardItem(content: "Test item")
        storage.save(item)
        storage.togglePin(item.id) // Pin
        storage.togglePin(item.id) // Unpin

        let items = storage.loadAll()
        XCTAssertFalse(items.first?.isPinned ?? true)
    }

    func testTogglePin_PinnedItemExpiresAtNil() {
        let item = ClipboardItem(content: "Test item")
        storage.save(item)

        XCTAssertNotNil(storage.loadAll().first?.expiresAt)

        storage.togglePin(item.id)

        let savedItem = storage.loadAll().first
        XCTAssertTrue(savedItem?.isPinned ?? false)
        XCTAssertNil(savedItem?.expiresAt)
    }

    // MARK: - Search Tests

    func testSearch_ByContent() {
        storage.save(ClipboardItem(content: "Apple fruit"))
        storage.save(ClipboardItem(content: "Banana fruit"))
        storage.save(ClipboardItem(content: "Car vehicle"))

        let results = storage.search(query: "fruit")

        XCTAssertEqual(results.count, 2)
    }

    func testSearch_ByPartialContent() {
        storage.save(ClipboardItem(content: "Hello World"))
        storage.save(ClipboardItem(content: "Hello Swift"))
        storage.save(ClipboardItem(content: "Goodbye"))

        let results = storage.search(query: "Hello")

        XCTAssertEqual(results.count, 2)
    }

    func testSearch_EmptyQuery_ReturnsAll() {
        storage.save(ClipboardItem(content: "Item 1"))
        storage.save(ClipboardItem(content: "Item 2"))

        let results = storage.search(query: "")

        XCTAssertEqual(results.count, 2)
    }

    func testSearch_BySourceApp() {
        storage.save(ClipboardItem(content: "Content 1", sourceApp: "Safari"))
        storage.save(ClipboardItem(content: "Content 2", sourceApp: "Chrome"))
        storage.save(ClipboardItem(content: "Content 3", sourceApp: "Safari"))

        let results = storage.search(query: "", sourceApp: "Safari")

        XCTAssertEqual(results.count, 2)
    }

    func testSearch_ByContentAndSourceApp() {
        storage.save(ClipboardItem(content: "Apple Safari", sourceApp: "Safari"))
        storage.save(ClipboardItem(content: "Apple Chrome", sourceApp: "Chrome"))
        storage.save(ClipboardItem(content: "Banana Safari", sourceApp: "Safari"))

        let results = storage.search(query: "Apple", sourceApp: "Safari")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Apple Safari")
    }

    func testSearch_NoMatch() {
        storage.save(ClipboardItem(content: "Hello World"))

        let results = storage.search(query: "xyz123notfound")

        XCTAssertEqual(results.count, 0)
    }

    func testSearch_CaseInsensitive() {
        storage.save(ClipboardItem(content: "Hello World"))

        let results = storage.search(query: "HELLO")

        // SQLite LIKE 默认不区分大小写
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Get Unique Source Apps Tests

    func testGetUniqueSourceApps() {
        storage.save(ClipboardItem(content: "1", sourceApp: "Safari"))
        storage.save(ClipboardItem(content: "2", sourceApp: "Chrome"))
        storage.save(ClipboardItem(content: "3", sourceApp: "Safari"))
        storage.save(ClipboardItem(content: "4", sourceApp: nil))

        let apps = storage.getUniqueSourceApps()

        XCTAssertEqual(apps.count, 2)
        XCTAssertTrue(apps.contains("Safari"))
        XCTAssertTrue(apps.contains("Chrome"))
    }

    func testGetUniqueSourceApps_EmptyDatabase() {
        let apps = storage.getUniqueSourceApps()
        XCTAssertEqual(apps.count, 0)
    }

    func testGetUniqueSourceApps_OrderedAlphabetically() {
        storage.save(ClipboardItem(content: "1", sourceApp: "Zebra"))
        storage.save(ClipboardItem(content: "2", sourceApp: "Apple"))
        storage.save(ClipboardItem(content: "3", sourceApp: "Chrome"))

        let apps = storage.getUniqueSourceApps()

        XCTAssertEqual(apps, ["Apple", "Chrome", "Zebra"])
    }

    // MARK: - Refresh Timestamp Tests

    func testRefreshTimestamp() {
        let item = ClipboardItem(content: "Test")
        storage.save(item)

        let originalTime = storage.loadAll().first?.createdAt

        // 等待一小段时间
        Thread.sleep(forTimeInterval: 0.1)

        storage.refreshTimestamp(item.id)

        let refreshedItem = storage.loadAll().first
        XCTAssertGreaterThan(refreshedItem?.createdAt ?? Date.distantPast, originalTime ?? Date.distantFuture)
    }

    // MARK: - Clean Expired Items Tests

    func testCleanExpiredItems_RemovesExpired() {
        // 创建一个已过期的项目
        let expiredItem = ClipboardItem(
            id: UUID(),
            content: "Expired",
            contentType: .text,
            sourceApp: nil,
            sourceAppBundle: nil,
            createdAt: Date(),
            isPinned: false,
            expiresAt: Date().addingTimeInterval(-3600), // 1小时前过期
            imageData: nil,
            ocrText: nil
        )
        storage.save(expiredItem)

        storage.cleanExpiredItems()

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 0)
    }

    func testCleanExpiredItems_KeepsNonExpired() {
        let futureItem = ClipboardItem(
            id: UUID(),
            content: "Future",
            contentType: .text,
            sourceApp: nil,
            sourceAppBundle: nil,
            createdAt: Date(),
            isPinned: false,
            expiresAt: Date().addingTimeInterval(3600), // 1小时后过期
            imageData: nil,
            ocrText: nil
        )
        storage.save(futureItem)

        storage.cleanExpiredItems()

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 1)
    }

    func testCleanExpiredItems_KeepsPinned() {
        // 创建一个已过期但已置顶的项目
        let pinnedExpiredItem = ClipboardItem(
            id: UUID(),
            content: "Pinned Expired",
            contentType: .text,
            sourceApp: nil,
            sourceAppBundle: nil,
            createdAt: Date(),
            isPinned: true,
            expiresAt: Date().addingTimeInterval(-3600),
            imageData: nil,
            ocrText: nil
        )
        storage.save(pinnedExpiredItem)

        storage.cleanExpiredItems()

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 1)
    }

    // MARK: - Limit History Count Tests

    func testLimitHistoryCount_RemovesOldest() {
        // 保存 10 个项目
        for i in 1...10 {
            storage.save(ClipboardItem(content: "Item \(i)"))
            Thread.sleep(forTimeInterval: 0.05)
        }

        // 限制为 5 个
        storage.limitHistoryCount(customLimit: 5)

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 5)
        // 应该保留最新的 5 个
        XCTAssertEqual(items.first?.content, "Item 10")
    }

    func testLimitHistoryCount_KeepsPinnedItems() {
        // 保存一些项目
        for i in 1...5 {
            let item = ClipboardItem(content: "Item \(i)")
            storage.save(item)
            Thread.sleep(forTimeInterval: 0.05)
        }

        // 置顶第一个（最旧的）
        let items = storage.loadAll()
        if let oldestItem = items.last {
            storage.togglePin(oldestItem.id)
        }

        // 限制为 1 个
        storage.limitHistoryCount(customLimit: 1)

        let remainingItems = storage.loadAll()
        // 应该保留置顶的项目和最新的一个
        XCTAssertEqual(remainingItems.count, 2)
    }

    func testLimitHistoryCount_NoLimitWhenZero() {
        for i in 1...10 {
            storage.save(ClipboardItem(content: "Item \(i)"))
        }

        // 限制为 0 应该使用默认值 500
        storage.limitHistoryCount(customLimit: 0)

        let items = storage.loadAll()
        XCTAssertEqual(items.count, 10) // 所有项目都应保留
    }

    // MARK: - Update OCR Text Tests

    func testUpdateOCRText() {
        let item = ClipboardItem(content: "[Image]", contentType: .image)
        storage.save(item)

        let expectation = XCTestExpectation(description: "OCR update")

        storage.updateOCRText(item.id, text: "Recognized text")

        // 等待异步更新完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let items = self.storage.loadAll()
            XCTAssertEqual(items.first?.ocrText, "Recognized text")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Special Content Tests

    func testSave_ChineseContent() {
        let item = ClipboardItem(content: "你好世界")
        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.first?.content, "你好世界")
    }

    func testSave_EmojiContent() {
        let item = ClipboardItem(content: "Hello 🌍🎉")
        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.first?.content, "Hello 🌍🎉")
    }

    func testSave_VeryLongContent() {
        let longContent = String(repeating: "a", count: 10000)
        let item = ClipboardItem(content: longContent)
        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.first?.content.count, 10000)
    }

    func testSave_SpecialCharacters() {
        let specialContent = "Test\"with'quotes\\and\\backslash\nnewline\ttab"
        let item = ClipboardItem(content: specialContent)
        storage.save(item)

        let items = storage.loadAll()
        XCTAssertEqual(items.first?.content, specialContent)
    }
}
