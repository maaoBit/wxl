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

                    DispatchQueue.global(qos: .utility).async {
                        let items = ClipboardStorage.shared.loadAllLight()
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
