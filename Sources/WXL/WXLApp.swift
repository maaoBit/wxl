//
//  WXLApp.swift
//  WXL - macOS Clipboard History Manager
//
//  A beautiful clipboard manager with Liquid Glass UI
//

import SwiftUI

@main
struct WXLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // 隐藏主窗口，使用面板显示
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var clipboardItems: [ClipboardItem] = [] {
        didSet {
            // 确保数据变化时通知观察者
            objectWillChange.send()
        }
    }
    @Published var searchText: String = "" {
        didSet {
            // 确保数据变化时通知观察者
            objectWillChange.send()
        }
    }
    @Published var selectedIndex: Int = 0

    // 获取过滤后的项目列表
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardItems
        }
        return clipboardItems.filter { item in
            item.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    // 获取当前选中的项目
    var selectedItem: ClipboardItem? {
        filteredItems.safe(at: selectedIndex)
    }

    private init() {}
}
