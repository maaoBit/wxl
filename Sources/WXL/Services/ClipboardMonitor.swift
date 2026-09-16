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
    /// 我们自己写入剪贴板后的预期 changeCount；轮询时仅忽略等于该值的那次变化
    /// （布尔标志会在「粘贴后 0.5s 内用户又复制」时把用户的复制一并吞掉）
    private var ignoredChangeCount: Int?

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

    /// 忽略我们自己写回剪贴板引起的那次变化（用于粘贴操作）。
    /// 须在写入剪贴板之前调用
    func setIgnoreNextChange() {
        ignoredChangeCount = pasteboard.changeCount + 1
    }

    private func checkForChanges() {
        let currentCount = pasteboard.changeCount
        Logger.debug("checkForChanges: currentCount=\(currentCount), storedCount=\(changeCount)", category: .clipboard)
        guard currentCount != changeCount else { return }

        Logger.log("Clipboard changed! old=\(changeCount), new=\(currentCount)", category: .clipboard)

        changeCount = currentCount

        // 只跳过我们自己引起的那次变化；期间用户的其他复制正常捕获
        if let ignored = ignoredChangeCount {
            ignoredChangeCount = nil
            if currentCount == ignored {
                Logger.debug("Ignoring own paste change (count=\(currentCount))", category: .clipboard)
                return
            }
        }

        processClipboardContent()
    }

    private func processClipboardContent() {
        // 获取来源应用
        let sourceApp = getActiveApplication()

        // 排除名单内的应用（如密码管理器）不进入历史
        if AppExclusion.isExcluded(sourceApp?.bundleIdentifier) {
            Logger.debug("Skipping capture from excluded app: \(sourceApp?.bundleIdentifier ?? "?")", category: .clipboard)
            return
        }

        guard let item = ClipboardItemFactory.makeItem(
            from: pasteboard,
            sourceApp: sourceApp?.localizedName,
            sourceAppBundle: sourceApp?.bundleIdentifier
        ) else {
            Logger.debug("No recognizable clipboard content", category: .clipboard)
            return
        }

        onNewClip?(item)

        // 图片条目异步 OCR 识别
        if item.contentType == .image, let imageData = item.imageData {
            performOCR(on: imageData, item: item)
        }
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

                    // 内存内补丁 ocrText，避免全量 loadAllLight 重载打乱面板状态
                    DispatchQueue.main.async {
                        var items = AppState.shared.clipboardItems
                        if let index = items.firstIndex(where: { $0.id == item.id }) {
                            items[index].ocrText = recognizedText
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
