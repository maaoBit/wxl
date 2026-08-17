//
//  ClipboardWriterTests.swift
//  WXLTests
//
//  Unit tests for paste-back logic (ClipboardWriter)
//

import XCTest
import AppKit
@testable import WXL

/// ClipboardWriter 使用的剪贴板写入 mock，按顺序记录调用
final class MockPasteboardWriter: PasteboardWriting {
    enum Call: Equatable {
        case clear
        case writeObjectURLs([String])
        case writeObjectImages(Int)
        case setString(String)
    }

    private(set) var calls: [Call] = []

    func clearContents() -> Int {
        calls.append(.clear)
        return 0
    }

    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool {
        if objects.first is NSURL {
            let urls = objects.compactMap { $0 as? NSURL }
            calls.append(.writeObjectURLs(urls.map { $0.absoluteString! }))
        } else {
            calls.append(.writeObjectImages(objects.count))
        }
        return true
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        calls.append(.setString(string))
        return true
    }
}

final class ClipboardWriterTests: XCTestCase {

    // MARK: - Text Items

    func testWrite_TextItem_WritesString() {
        let item = ClipboardItem(content: "hello")
        let writer = MockPasteboardWriter()

        ClipboardWriter.write(item, to: writer)

        XCTAssertEqual(writer.calls, [.clear, .setString("hello")])
    }

    // MARK: - File Items

    func testWrite_FileItem_WritesURLs() {
        let item = ClipboardItem(
            content: "folder",
            contentType: .filePath,
            fileURLs: ["/Users/maao/Documents/folder", "/tmp/a.txt"]
        )
        let writer = MockPasteboardWriter()

        ClipboardWriter.write(item, to: writer)

        XCTAssertEqual(writer.calls, [
            .clear,
            .writeObjectURLs(["file:///Users/maao/Documents/folder", "file:///tmp/a.txt"])
        ])
    }

    func testWrite_FileItem_EmptyFileURLs_FallsBackToString() {
        let item = ClipboardItem(content: "folder", contentType: .filePath, fileURLs: [])
        let writer = MockPasteboardWriter()

        ClipboardWriter.write(item, to: writer)

        XCTAssertEqual(writer.calls, [.clear, .setString("folder")])
    }

    // MARK: - Image Items

    func testWrite_ImageItem_WithImageData_WritesImage() {
        let item = ClipboardItem(content: "[Image]", contentType: .image)
        let writer = MockPasteboardWriter()

        ClipboardWriter.write(item, to: writer, imageData: Self.makePNGData())

        XCTAssertEqual(writer.calls, [.clear, .writeObjectImages(1)])
    }

    func testWrite_ImageItem_WithoutImageData_WritesPlaceholder() {
        let item = ClipboardItem(content: "[Image]", contentType: .image)
        let writer = MockPasteboardWriter()

        ClipboardWriter.write(item, to: writer, imageData: nil)

        XCTAssertEqual(writer.calls, [.clear, .setString("[Image]")])
    }

    // MARK: - Helpers

    /// 构造一张 1x1 的真实 PNG 图片数据
    private static func makePNGData() -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.addRepresentation(rep)
        return image.tiffRepresentation!
    }
}
