//
//  FilterCategoryTests.swift
//  WXLTests
//
//  Unit tests for panel type-filter category mapping
//

import XCTest
@testable import WXL

final class FilterCategoryTests: XCTestCase {

    func testMatches_AllMatchesEverything() {
        for type in ContentType.allCases {
            XCTAssertTrue(FilterCategory.all.matches(type))
        }
    }

    func testMatches_TextCoversTextLikeTypes() {
        // 文本 chip 覆盖 text/code/email/phoneNumber，避免这些类型在筛选时“消失”
        XCTAssertTrue(FilterCategory.text.matches(.text))
        XCTAssertTrue(FilterCategory.text.matches(.code))
        XCTAssertTrue(FilterCategory.text.matches(.email))
        XCTAssertTrue(FilterCategory.text.matches(.phoneNumber))
    }

    func testMatches_DistinctCategories() {
        XCTAssertTrue(FilterCategory.link.matches(.url))
        XCTAssertFalse(FilterCategory.text.matches(.url))

        XCTAssertTrue(FilterCategory.file.matches(.filePath))
        XCTAssertFalse(FilterCategory.link.matches(.filePath))

        XCTAssertTrue(FilterCategory.image.matches(.image))
        XCTAssertFalse(FilterCategory.file.matches(.image))
    }

    func testAllCases_ExposeLabels() {
        XCTAssertEqual(FilterCategory.allCases.map(\.label), ["全部", "文本", "链接", "文件", "图片"])
    }
}
