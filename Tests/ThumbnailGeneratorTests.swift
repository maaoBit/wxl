//
//  ThumbnailGeneratorTests.swift
//  WXLTests
//
//  Unit tests for image thumbnail downsampling
//

import XCTest
import AppKit
@testable import WXL

final class ThumbnailGeneratorTests: XCTestCase {

    /// 生成纯色 PNG 测试图
    private func makeTestPNG(width: Int, height: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.red.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    func testGenerate_ReturnsDecodableThumbnail() {
        guard let source = makeTestPNG(width: 800, height: 600) else {
            return XCTFail("测试图生成失败")
        }

        let thumbnail = ThumbnailGenerator.generate(from: source)

        XCTAssertNotNil(thumbnail)
        let image = thumbnail.flatMap { NSImage(data: $0) }
        XCTAssertNotNil(image, "缩略图应可解码")
        let maxSide = max(image!.size.width, image!.size.height)
        XCTAssertLessThanOrEqual(maxSide, ThumbnailGenerator.maxPixelSize + 1, "缩略图最长边应不超过上限")
    }

    func testGenerate_InvalidData_ReturnsNil() {
        XCTAssertNil(ThumbnailGenerator.generate(from: Data("not an image".utf8)))
        XCTAssertNil(ThumbnailGenerator.generate(from: Data()))
    }

    func testGenerate_SmallImage_NotUpscaled() {
        guard let source = makeTestPNG(width: 32, height: 32) else {
            return XCTFail("测试图生成失败")
        }

        let thumbnail = ThumbnailGenerator.generate(from: source)
        let image = thumbnail.flatMap { NSImage(data: $0) }
        XCTAssertNotNil(image)
        XCTAssertLessThanOrEqual(image!.size.width, 33, "小图不应被放大")
    }
}
