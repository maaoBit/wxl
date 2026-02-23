//
//  AppDelegate.swift
//  WXL
//
//  Handles app lifecycle, panel management, and global hotkeys
//

import SwiftUI
import KeyboardShortcuts
import AppKit
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: KeyboardHandlingPanel!
    private var clipboardMonitor: ClipboardMonitor!
    private var clipboardStorage: ClipboardStorage!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 初始化存储
        clipboardStorage = ClipboardStorage.shared

        // 加载现有数据
        AppState.shared.clipboardItems = clipboardStorage.loadAll()

        // 初始化剪贴板监听
        clipboardMonitor = ClipboardMonitor.shared
        clipboardMonitor.onNewClip = { [weak self] item in
            self?.handleNewClipboardItem(item)
        }
        clipboardMonitor.startMonitoring()

        // 设置面板
        setupPanel()

        // 设置菜单栏图标
        setupStatusItem()

        // 注册全局快捷键
        setupHotKeys()
    }

    private func setupPanel() {
        panel = KeyboardHandlingPanel()
        panel.delegate = self
    }

    private func setupStatusItem() {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // 使用 SF Symbol 作为图标
            button.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "WXL 剪贴板")
            button.image?.isTemplate = true  // 图标会根据系统主题自动调整颜色
        }

        // 设置点击动作
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.target = self

        // 设置右键菜单
        setupStatusItemMenu()
    }

    private func setupStatusItemMenu() {
        let menu = NSMenu()

        // 关于
        menu.addItem(NSMenuItem(title: "关于 WXL", action: #selector(showAbout), keyEquivalent: ""))

        // 分隔线
        menu.addItem(NSMenuItem.separator())

        // 设置
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ","))

        // 分隔线
        menu.addItem(NSMenuItem.separator())

        // 退出
        menu.addItem(NSMenuItem(title: "退出 WXL", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WXL 剪贴板管理器"
        alert.informativeText = "一款优雅的 macOS 剪贴板历史管理工具\n\n版本：1.0\n快捷键：⌘⇧C"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            // 创建设置窗口
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            settingsWindow.title = "WXL 设置"
            settingsWindow.contentViewController = hostingController
            settingsWindow.center()
            settingsWindow.isReleasedWhenClosed = false

            // 设置窗口为普通窗口（不是面板）
            settingsWindow.level = .normal
        }

        // 显示并激活窗口
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func setupHotKeys() {
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.togglePanel()
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            panel.hide()
        } else {
            panel.show()
        }
    }

    private func handleNewClipboardItem(_ item: ClipboardItem) {
        Logger.debug("New clipboard item detected: \(item.previewText)", category: .clipboard)
        let saved = clipboardStorage.save(item)
        Logger.debug("Save result: \(saved)", category: .clipboard)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let items = self.clipboardStorage.loadAll()
            Logger.debug("Loaded \(items.count) items from database", category: .database)
            AppState.shared.clipboardItems = items
            Logger.debug("Updated AppState with \(items.count) items", category: .ui)
            // 如果面板正在显示，重置选择到第一项
            if self.panel.isVisible {
                AppState.shared.selectedIndex = 0
                Logger.debug("Panel is visible, reset selection to 0", category: .ui)
            }
        }
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === panel {
            panel.hide()
        }
    }
}

// MARK: - Custom Panel with Keyboard Handling
class KeyboardHandlingPanel: NSPanel {
    private var hostingView: NSHostingView<PanelView>? = nil

    override var acceptsFirstResponder: Bool {
        return true
    }

    override var canBecomeKey: Bool {
        return true
    }

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 450),
            styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    func refreshContentView() {
        let contentView = PanelView()
        let newHostingView = NSHostingView(rootView: contentView)
        newHostingView.autoresizingMask = [.width, .height]
        newHostingView.frame = NSRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height)

        // 移除旧的 hostingView
        if let oldHostingView = self.contentView as? NSHostingView<PanelView> {
            oldHostingView.removeFromSuperview()
        }

        self.contentView = newHostingView
        hostingView = newHostingView
    }

    func show() {
        // 刷新内容视图以显示最新数据
        refreshContentView()

        // 获取鼠标位置
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        let panelWidth: CGFloat = 700
        let panelHeight: CGFloat = 450

        var panelX = mouseLocation.x - panelWidth / 2
        var panelY = mouseLocation.y - panelHeight / 2

        // 确保面板在屏幕内
        panelX = max(screenFrame.minX, min(panelX, screenFrame.maxX - panelWidth))
        panelY = max(screenFrame.minY, min(panelY, screenFrame.maxY - panelHeight))

        setFrameOrigin(NSPoint(x: panelX, y: panelY))
        makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // 重置状态
        AppState.shared.selectedIndex = 0
        AppState.shared.searchText = ""
    }

    func hide() {
        // 清空搜索文本
        AppState.shared.searchText = ""
        orderOut(nil)

        // 隐藏应用，macOS 会自动将焦点返回到之前的应用
        NSApplication.shared.hide(nil)
    }

    // 直接处理键盘事件
    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags

        switch keyCode {
        case 53: // Escape
            hide()

        case 36: // Return
            if flags.contains(.command) {
                // Cmd+Enter - 执行智能动作
                performAction()
            } else {
                // Enter - 粘贴
                pasteSelected()
            }

        case 126: // Up Arrow
            AppState.shared.selectedIndex = max(0, AppState.shared.selectedIndex - 1)

        case 125: // Down Arrow
            let count = AppState.shared.filteredItems.count
            if count > 0 {
                AppState.shared.selectedIndex = min(count - 1, AppState.shared.selectedIndex + 1)
            }

        case 51: // Backspace
            // 删除搜索文本的最后一个字符
            if !AppState.shared.searchText.isEmpty {
                AppState.shared.searchText.removeLast()
            }

        case 48: // Tab
            // Tab 键 - 暂不处理
            break

        default:
            // 处理字符键
            if let chars = event.characters, chars.count == 1 {
                let char = chars.lowercased()

                // Cmd+P - 置顶
                if flags.contains(.command) && char == "p" {
                    togglePinSelected()
                    return
                }

                // Cmd+D - 删除
                if flags.contains(.command) && char == "d" {
                    deleteSelected()
                    return
                }

                // 其他字符添加到搜索文本（仅当没有按 Cmd 时）
                if !flags.contains(.command) && char != "\u{7f}" {
                    AppState.shared.searchText += char
                }
            }
        }
    }

    private func pasteSelected() {
        guard let item = AppState.shared.selectedItem else { return }

        // 刷新时间戳，将该项移到顶部（如果是置顶项则不移动）
        if !item.isPinned {
            ClipboardStorage.shared.refreshTimestamp(item.id)
            // 重新加载列表
            let items = ClipboardStorage.shared.loadAll()
            AppState.shared.clipboardItems = items
            // 该项现在应该在顶部了（置顶项之后）
            AppState.shared.selectedIndex = 0
        }

        // 通知监听器忽略即将发生的剪贴板变化
        ClipboardMonitor.shared.setIgnoreNextChange()

        // 复制到剪贴板
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)

        // 关闭面板
        orderOut(nil)

        // 隐藏应用，macOS 会自动将焦点返回到之前的应用
        NSApplication.shared.hide(nil)

        // 延迟粘贴（等待焦点完全恢复）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.simulatePaste()
        }
    }

    private func performAction() {
        guard let item = AppState.shared.selectedItem else { return }

        switch item.contentType {
        case .url:
            // 在浏览器中打开
            if let url = URL(string: item.content) {
                NSWorkspace.shared.open(url)
            }
        case .filePath:
            // 在 Finder 中显示
            let expandedPath = (item.content as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            if FileManager.default.fileExists(atPath: expandedPath) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(url.deletingLastPathComponent())
            }
        case .email:
            // 发送邮件
            if let url = URL(string: "mailto:\(item.content)") {
                NSWorkspace.shared.open(url)
            }
        case .phoneNumber:
            // FaceTime
            let cleaned = item.content.replacingOccurrences(of: "\\s|\\-|\\(|\\)", with: "", options: .regularExpression)
            if let url = URL(string: "facetime://\(cleaned)") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }

    private func deleteSelected() {
        guard let item = AppState.shared.selectedItem else { return }

        // 从存储中删除
        ClipboardStorage.shared.delete(item.id)

        // 重新加载
        AppState.shared.clipboardItems = ClipboardStorage.shared.loadAll()

        // 调整选择位置
        if AppState.shared.selectedIndex >= AppState.shared.filteredItems.count {
            AppState.shared.selectedIndex = max(0, AppState.shared.filteredItems.count - 1)
        }
    }

    private func togglePinSelected() {
        guard let item = AppState.shared.selectedItem else { return }

        // 记录置顶状态
        let wasPinned = item.isPinned

        // 切换置顶状态
        ClipboardStorage.shared.togglePin(item.id)

        // 重新加载
        let items = ClipboardStorage.shared.loadAll()
        AppState.shared.clipboardItems = items

        // 更新选择焦点
        if !wasPinned {
            // 如果是置顶操作，该项会移动到顶部，选择焦点也移到顶部
            AppState.shared.selectedIndex = 0
        } else {
            // 如果是取消置顶，找到该项的新位置
            if let newIndex = items.firstIndex(where: { $0.id == item.id }) {
                AppState.shared.selectedIndex = newIndex
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let pasteDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let pasteUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        pasteDown?.flags = .maskCommand
        pasteUp?.flags = .maskCommand

        pasteDown?.post(tap: .cgAnnotatedSessionEventTap)
        pasteUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
