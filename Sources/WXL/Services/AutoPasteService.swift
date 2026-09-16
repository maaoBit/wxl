//
//  AutoPasteService.swift
//  WXL
//
//  Pastes the selected item into the previously frontmost app (simulated ⌘V)
//

import AppKit

/// 选中条目后自动向此前台应用模拟 ⌘V。
/// 需要辅助功能权限；未授权时静默跳过（行为退化为普通复制）
enum AutoPasteService {

    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "autoPasteAfterSelection")
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 面板隐藏、焦点回到原应用后发送 ⌘V。
    /// 须在面板已开始隐藏之后调用（延迟是给系统切换焦点留时间）
    static func fireIfEnabled() {
        guard isEnabled, isTrusted else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand

            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
