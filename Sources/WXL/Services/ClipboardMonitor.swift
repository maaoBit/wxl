//
//  ClipboardMonitor.swift
//  WXL
//
//  Monitors system clipboard changes
//

import AppKit
import Vision
import Combine

class ClipboardMonitor: ObservableObject {
    static let shared = ClipboardMonitor()

    private var changeCount: Int
    private var timer: Timer?
    private var pasteboard: NSPasteboard
    private var isPasting: Bool = false // 标志位：是否正在粘贴
    private var ignoreNextChange: Bool = false // 是否忽略下一次变化

    var onNewClip: ((ClipboardItem) -> Void)?

    private init() {
        self.pasteboard = NSPasteboard.general
        self.changeCount = pasteboard.changeCount
    }

    func startMonitoring() {
        // 每 0.5 秒检查一次剪贴板变化
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }

        // 确保在主线程运行
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// 忽略下一次剪贴板变化（用于粘贴操作）
    func setIgnoreNextChange() {
        ignoreNextChange = true
    }

    private func checkForChanges() {
        let currentCount = pasteboard.changeCount
        Logger.debug("checkForChanges: currentCount=\(currentCount), storedCount=\(changeCount)", category: .clipboard)
        guard currentCount != changeCount else { return }

        Logger.log("Clipboard changed! old=\(changeCount), new=\(currentCount)", category: .clipboard)

        // 如果设置了忽略标志，跳过这次变化
        if ignoreNextChange {
            Logger.debug("Ignoring this change (ignoreNextChange=true)", category: .clipboard)
            changeCount = currentCount
            ignoreNextChange = false
            return
        }

        changeCount = currentCount
        processClipboardContent()
    }

    private func processClipboardContent() {
        // 获取来源应用
        let sourceApp = getActiveApplication()
        Logger.debug("processClipboardContent started, sourceApp: \(sourceApp?.localizedName ?? "nil")", category: .clipboard)
        
        // 检测顺序很重要：文件 > 图片 > 文本
        // 因为复制文件时可能同时有文件URL和图标数据
        
        // ========== 1. 首先检测文件 ==========
        let hasTextContent = pasteboard.string(forType: .string) != nil
        Logger.debug("hasTextContent=\(hasTextContent)", category: .clipboard)
        
        // 检查 NSFilenamesPboardType（多文件）
        if let fileURLsData = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           !fileURLsData.isEmpty {
            Logger.debug("Found NSFilenamesPboardType: \(fileURLsData)", category: .clipboard)
            let existingFiles = fileURLsData.filter { FileManager.default.fileExists(atPath: $0) }
            Logger.debug("Existing files: \(existingFiles.count)/\(fileURLsData.count)", category: .clipboard)
            
            if !existingFiles.isEmpty && !hasTextContent {
                // 检查是否全部是图片文件
                let imageFiles = existingFiles.filter { isImageFile($0) }
                if imageFiles.count == existingFiles.count && !imageFiles.isEmpty {
                    // 全部是图片文件，读取图片数据
                    if let firstFile = imageFiles.first,
                       let image = NSImage(contentsOf: URL(fileURLWithPath: firstFile)),
                       let tiffData = image.tiffRepresentation {
                        let item = ClipboardItem(
                            content: "[Image]",
                            contentType: .image,
                            sourceApp: sourceApp?.localizedName,
                            sourceAppBundle: sourceApp?.bundleIdentifier,
                            imageData: tiffData
                        )
                        Logger.log("Calling onNewClip for image files", category: .clipboard)
                        onNewClip?(item)
                        performOCR(on: tiffData, item: item)
                        return
                    }
                }
                
                // 非图片文件，保存为文件路径
                let fileNames = existingFiles.map { ($0 as NSString).lastPathComponent }
                let previewText = fileNames.count == 1 ? fileNames[0] : "\(fileNames.count) 个文件"
                let item = ClipboardItem(
                    content: previewText,
                    contentType: .filePath,
                    sourceApp: sourceApp?.localizedName,
                    sourceAppBundle: sourceApp?.bundleIdentifier,
                    fileURLs: existingFiles
                )
                Logger.log("Calling onNewClip for file (NSFilenamesPboardType)", category: .clipboard)
                onNewClip?(item)
                return
            }
        }
        
        // 检查单个 fileURL
        if let fileURLData = pasteboard.data(forType: .fileURL),
           let fileURLString = String(data: fileURLData, encoding: .utf8),
           !fileURLString.isEmpty {
            Logger.debug("Found fileURL: \(fileURLString)", category: .clipboard)
            
            if let url = URL(string: fileURLString),
               url.isFileURL,
               FileManager.default.fileExists(atPath: url.path) {
                Logger.debug("fileURL is valid file, hasTextContent=\(hasTextContent)", category: .clipboard)
                
                if !hasTextContent {
                    // 检查是否是图片文件
                    if isImageFile(url.path),
                       let image = NSImage(contentsOf: url),
                       let tiffData = image.tiffRepresentation {
                        let item = ClipboardItem(
                            content: "[Image]",
                            contentType: .image,
                            sourceApp: sourceApp?.localizedName,
                            sourceAppBundle: sourceApp?.bundleIdentifier,
                            imageData: tiffData
                        )
                        Logger.log("Calling onNewClip for image file", category: .clipboard)
                        onNewClip?(item)
                        performOCR(on: tiffData, item: item)
                        return
                    }
                    
                    // 非图片文件
                    let item = ClipboardItem(
                        content: url.lastPathComponent,
                        contentType: .filePath,
                        sourceApp: sourceApp?.localizedName,
                        sourceAppBundle: sourceApp?.bundleIdentifier,
                        fileURLs: [fileURLString]
                    )
                    Logger.log("Calling onNewClip for file (single fileURL)", category: .clipboard)
                    onNewClip?(item)
                    return
                }
            }
        }
        
        // ========== 2. 检测纯图片数据（剪贴板中的截图等） ==========
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png, .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.tiff"),
            NSPasteboard.PasteboardType("public.image"),
            NSPasteboard.PasteboardType("com.apple.pict"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("com.microsoft.bmp")
        ]

        for imageType in imageTypes {
            if let imageData = pasteboard.data(forType: imageType) {
                Logger.debug("Found image type: \(imageType.rawValue)", category: .clipboard)
                let item = ClipboardItem(
                    content: "[Image]",
                    contentType: .image,
                    sourceApp: sourceApp?.localizedName,
                    sourceAppBundle: sourceApp?.bundleIdentifier,
                    imageData: imageData
                )
                Logger.log("Calling onNewClip for image", category: .clipboard)
                onNewClip?(item)
                performOCR(on: imageData, item: item)
                return
            }
        }
        
        // ========== 3. 检测文本 ==========
        Logger.debug("Checking for text content...", category: .clipboard)
        guard let content = pasteboard.string(forType: .string),
              !content.isEmpty else {
            Logger.debug("No text content found, returning", category: .clipboard)
            return
        }

        Logger.log("Found text content: \(content.prefix(50))...", category: .clipboard)

        let contentType = ClipboardItem.detectContentType(content)
        let item = ClipboardItem(
            content: content,
            contentType: contentType,
            sourceApp: sourceApp?.localizedName,
            sourceAppBundle: sourceApp?.bundleIdentifier
        )
        Logger.log("Calling onNewClip for text, contentType=\(contentType)", category: .clipboard)
        onNewClip?(item)
    }
    
    /// 判断文件是否是图片类型（基于扩展名）
    private func isImageFile(_ path: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
        let ext = (path as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    private func getActiveApplication() -> NSRunningApplication? {
        // 获取当前激活的应用
        return NSWorkspace.shared.runningApplications.first { $0.isActive }
    }

    private func performOCR(on imageData: Data, item: ClipboardItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let nsImage = NSImage(data: imageData),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return
            }

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else { return }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }

                let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")

                if !recognizedText.isEmpty {
                    ClipboardStorage.shared.updateOCRTextSync(item.id, text: recognizedText)

                    DispatchQueue.global(qos: .utility).async {
                        let items = ClipboardStorage.shared.loadAll()
                        DispatchQueue.main.async {
                            AppState.shared.clipboardItems = items
                        }
                    }
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}
