//
//  ClipboardItemFactory.swift
//  WXL
//
//  Builds ClipboardItem from pasteboard data (pure logic, testable)
//

import AppKit

/// 抽象读取 NSPasteboard 的接口，便于测试注入 mock
protocol PasteboardReading {
    func propertyList(forType type: NSPasteboard.PasteboardType) -> Any?
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
    func string(forType type: NSPasteboard.PasteboardType) -> String?
}

extension NSPasteboard: PasteboardReading {}

/// 从剪贴板数据构建 ClipboardItem
/// 检测顺序：文件 > 图片 > 文本（复制文件时可能同时有文件 URL 和图标数据）
enum ClipboardItemFactory {

    /// 剪贴板中图片数据的候选类型
    static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png, .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.png"),
        NSPasteboard.PasteboardType("public.tiff"),
        NSPasteboard.PasteboardType("public.image"),
        NSPasteboard.PasteboardType("com.apple.pict"),
        NSPasteboard.PasteboardType("com.compuserve.gif"),
        NSPasteboard.PasteboardType("com.microsoft.bmp")
    ]

    /// 从剪贴板读取数据并构建条目；无可识别内容时返回 nil
    /// - Parameters:
    ///   - pasteboard: 剪贴板数据源
    ///   - sourceApp: 来源应用名称
    ///   - sourceAppBundle: 来源应用 Bundle ID
    /// - Returns: 构建好的条目，或 nil（剪贴板无可识别内容）
    static func makeItem(
        from pasteboard: PasteboardReading,
        sourceApp: String? = nil,
        sourceAppBundle: String? = nil
    ) -> ClipboardItem? {
        // ========== 1. 首先检测文件 ==========
        // 检查 NSFilenamesPboardType（多文件）
        if let fileURLsData = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           !fileURLsData.isEmpty {
            let existingFiles = fileURLsData.filter { FileManager.default.fileExists(atPath: $0) }
            if !existingFiles.isEmpty {
                // 所有文件都保存为 filePath 类型，不区分图片
                let fileNames = existingFiles.map { ($0 as NSString).lastPathComponent }
                let previewText = fileNames.count == 1 ? fileNames[0] : "\(fileNames.count) 个文件"
                return ClipboardItem(
                    content: previewText,
                    contentType: .filePath,
                    sourceApp: sourceApp,
                    sourceAppBundle: sourceAppBundle,
                    fileURLs: existingFiles
                )
            }
        }

        // 检查单个 fileURL（仅当剪贴板中没有文本时才视为文件复制）
        let hasTextContent = pasteboard.string(forType: .string) != nil
        if let fileURLData = pasteboard.data(forType: .fileURL),
           let fileURLString = String(data: fileURLData, encoding: .utf8),
           !fileURLString.isEmpty,
           let url = URL(string: fileURLString),
           url.isFileURL,
           FileManager.default.fileExists(atPath: url.path),
           !hasTextContent {
            // 保存纯路径，而不是 file:// URL
            return ClipboardItem(
                content: url.lastPathComponent,
                contentType: .filePath,
                sourceApp: sourceApp,
                sourceAppBundle: sourceAppBundle,
                fileURLs: [url.path]
            )
        }

        // ========== 2. 检测纯图片数据（剪贴板中的截图等） ==========
        for imageType in imageTypes {
            if let imageData = pasteboard.data(forType: imageType) {
                return ClipboardItem(
                    content: "[Image]",
                    contentType: .image,
                    sourceApp: sourceApp,
                    sourceAppBundle: sourceAppBundle,
                    imageData: imageData
                )
            }
        }

        // ========== 3. 检测文本 ==========
        guard let content = pasteboard.string(forType: .string),
              !content.isEmpty else {
            return nil
        }

        return ClipboardItem(
            content: content,
            contentType: ClipboardItem.detectContentType(content),
            sourceApp: sourceApp,
            sourceAppBundle: sourceAppBundle
        )
    }
}
