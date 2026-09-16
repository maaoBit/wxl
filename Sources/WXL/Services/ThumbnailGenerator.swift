//
//  ThumbnailGenerator.swift
//  WXL
//
//  Downsamples image data to small PNG thumbnails (ImageIO, low memory)
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 图片缩略图生成（ImageIO 降采样，避免全尺寸解码）
enum ThumbnailGenerator {

    /// 缩略图最长边像素
    static let maxPixelSize: CGFloat = 128

    /// 从图片数据生成 PNG 缩略图；无法解码时返回 nil
    static func generate(from imageData: Data, maxPixelSize: CGFloat = ThumbnailGenerator.maxPixelSize) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return encodePNG(cgImage)
    }

    private static func encodePNG(_ cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
}
