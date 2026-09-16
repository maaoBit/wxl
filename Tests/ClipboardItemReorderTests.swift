//
//  ClipboardItemReorderTests.swift
//  WXLTests
//
//  Unit tests for reorderAfterUse (使用后重排：粘贴项移到所在分区首位)
//

import XCTest
@testable import WXL

final class ClipboardItemReorderTests: XCTestCase {

    private func pinned(_ content: String) -> ClipboardItem {
        var item = ClipboardItem(content: content)
        item.isPinned = true
        return item
    }

    // MARK: - Pinned Item Reorder

    func testReorderAfterUse_SecondPinnedItemBecomesFirst() {
        let pinA = pinned("pinA")
        let pinB = pinned("pinB")
        let normal = ClipboardItem(content: "normal")
        // 与 DB 排序 ORDER BY isPinned DESC, createdAt DESC 一致的列表顺序
        let items = [pinA, pinB, normal]

        let result = ClipboardItem.reorderAfterUse(items, usedItemId: pinB.id)

        // 使用第二个置顶项后应成为置顶区第一
        XCTAssertEqual(result.map(\.id), [pinB.id, pinA.id, normal.id])
    }

    func testReorderAfterUse_FirstPinnedItemStaysFirst() {
        let pinA = pinned("pinA")
        let pinB = pinned("pinB")
        let normal = ClipboardItem(content: "normal")
        let items = [pinA, pinB, normal]

        let result = ClipboardItem.reorderAfterUse(items, usedItemId: pinA.id)

        XCTAssertEqual(result.map(\.id), [pinA.id, pinB.id, normal.id])
    }

    func testReorderAfterUse_SinglePinnedItem_NoChange() {
        let pin = pinned("pin")
        let normal = ClipboardItem(content: "normal")
        let items = [pin, normal]

        let result = ClipboardItem.reorderAfterUse(items, usedItemId: pin.id)

        XCTAssertEqual(result.map(\.id), [pin.id, normal.id])
    }

    // MARK: - Unpinned Item Reorder（保持既有行为）

    func testReorderAfterUse_UnpinnedGoesAfterPinnedBlock() {
        let pin = pinned("pin")
        let n1 = ClipboardItem(content: "n1")
        let n2 = ClipboardItem(content: "n2")
        let items = [pin, n1, n2]

        let result = ClipboardItem.reorderAfterUse(items, usedItemId: n2.id)

        XCTAssertEqual(result.map(\.id), [pin.id, n2.id, n1.id])
    }

    func testReorderAfterUse_AllUnpinned_MovesToTop() {
        let n1 = ClipboardItem(content: "n1")
        let n2 = ClipboardItem(content: "n2")
        let items = [n1, n2]

        let result = ClipboardItem.reorderAfterUse(items, usedItemId: n2.id)

        XCTAssertEqual(result.map(\.id), [n2.id, n1.id])
    }

    // MARK: - Edge Cases

    func testReorderAfterUse_UnknownId_NoChange() {
        let n1 = ClipboardItem(content: "n1")
        let n2 = ClipboardItem(content: "n2")
        let items = [n1, n2]

        let result = ClipboardItem.reorderAfterUse(items, usedItemId: UUID())

        XCTAssertEqual(result.map(\.id), [n1.id, n2.id])
    }
}
