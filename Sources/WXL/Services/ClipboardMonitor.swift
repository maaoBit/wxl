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
        guard pasteboard.changeCount != changeCount else { return }

        // 如果设置了忽略标志，跳过这次变化
        if ignoreNextChange {
            changeCount = pasteboard.changeCount
            ignoreNextChange = false
            return
        }

        changeCount = pasteboard.changeCount
        processClipboardContent()
    }

    private func processClipboardContent() {
        // 获取来源应用
        let sourceApp = getActiveApplication()

        // 检查图片
        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            let item = ClipboardItem(
                content: "[Image]",
                contentType: .image,
                sourceApp: sourceApp?.localizedName,
                sourceAppBundle: sourceApp?.bundleIdentifier,
                imageData: imageData
            )
            onNewClip?(item)
            performOCR(on: imageData, item: item)
            return
        }

        // 获取文本内容
        guard let content = pasteboard.string(forType: .string),
              !content.isEmpty else { return }

        // 检测内容类型
        let contentType = ClipboardItem.detectContentType(content)

        let item = ClipboardItem(
            content: content,
            contentType: contentType,
            sourceApp: sourceApp?.localizedName,
            sourceAppBundle: sourceApp?.bundleIdentifier
        )

        onNewClip?(item)
    }

    private func getActiveApplication() -> NSRunningApplication? {
        // 获取当前激活的应用
        return NSWorkspace.shared.runningApplications.first { $0.isActive }
    }

    private func performOCR(on imageData: Data, item: ClipboardItem) {
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation],
                  error == nil else { return }

            let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")

            if !recognizedText.isEmpty {
                // 只更新数据库，不直接修改 UI（避免线程安全问题）
                ClipboardStorage.shared.updateOCRText(item.id, text: recognizedText)

                // 触发 UI 重新加载（通过重新加载数据库）
                DispatchQueue.main.async { [weak self] in
                    guard self != nil else { return }
                    let items = ClipboardStorage.shared.loadAll()
                    AppState.shared.clipboardItems = items
                }
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}
