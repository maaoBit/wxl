//
//  WXLApp.swift
//  WXL - macOS Clipboard History Manager
//
//  A beautiful clipboard manager with Liquid Glass UI
//

import SwiftUI
import Combine

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

    @Published var clipboardItems: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var filteredItems: [ClipboardItem] = []
    @Published var selectedIndex: Int = 0

    // 获取当前选中的项目
    var selectedItem: ClipboardItem? {
        filteredItems.safe(at: selectedIndex)
    }

    private var cancellables = Set<AnyCancellable>()
    private let filterQueue = DispatchQueue(label: "com.wxl.search.filter", qos: .userInitiated)

    private init() {
        let debouncedSearch = $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)

        debouncedSearch
            .combineLatest($clipboardItems)
            .sink { [weak self] text, items in
                self?.updateFilteredItems(searchText: text, items: items)
            }
            .store(in: &cancellables)

        $clipboardItems
            .sink { [weak self] items in
                guard let self = self else { return }
                if self.searchText.isEmpty {
                    self.updateFilteredItems(searchText: "", items: items)
                }
            }
            .store(in: &cancellables)
    }

    private func updateFilteredItems(searchText: String, items: [ClipboardItem]) {
        filterQueue.async { [weak self] in
            guard let self = self else { return }
            let result: [ClipboardItem]
            if searchText.isEmpty {
                result = items
            } else {
                result = ClipboardStorage.shared.searchLight(query: searchText)
            }
            DispatchQueue.main.async {
                self.filteredItems = result
                if self.selectedIndex >= result.count {
                    self.selectedIndex = max(0, result.count - 1)
                }
            }
        }
    }
}
