//
//  ClipboardWriter.swift
//  WXL
//
//  Writes a ClipboardItem back to the pasteboard (pure logic, testable)
//

import AppKit

/// 抽象写入 NSPasteboard 的接口，便于测试注入 mock
protocol PasteboardWriting: AnyObject {
    @discardableResult
    func clearContents() -> Int
    @discardableResult
    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool
    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardWriting {}

/// 将历史条目写回剪贴板（按内容类型选择写入方式）
enum ClipboardWriter {

    /// 把条目写入指定剪贴板
    /// - Parameters:
    ///   - item: 要写回的历史条目
    ///   - pasteboard: 目标剪贴板
    ///   - imageData: 图片数据（轻量级列表中 imageData 为 nil 时由调用方按需从数据库加载）
    static func write(_ item: ClipboardItem, to pasteboard: PasteboardWriting, imageData: Data? = nil) {
        pasteboard.clearContents()

        if item.contentType == .image {
            if let imageData = imageData, let nsImage = NSImage(data: imageData) {
                pasteboard.writeObjects([nsImage] as [NSPasteboardWriting])
            } else {
                // 图片数据不可用时写入占位文本
                pasteboard.setString(item.content, forType: .string)
            }
        } else if item.contentType == .filePath, let fileURLs = item.fileURLs, !fileURLs.isEmpty {
            let urls = fileURLs.compactMap { URL(fileURLWithPath: $0) as NSURL }
            if !urls.isEmpty {
                pasteboard.writeObjects(urls.map { $0 as NSPasteboardWriting })
            }
        } else {
            pasteboard.setString(item.content, forType: .string)
        }
    }
}
