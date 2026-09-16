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
    @Published var selectedFilter: FilterCategory = .all
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

        // 搜索词或类型筛选变化：重查，选中项归零（用户预期从顶部开始看结果）
        Publishers.CombineLatest(debouncedSearch, $selectedFilter.removeDuplicates())
            .removeDuplicates(by: { $0 == $1 })
            .sink { [weak self] text, filter in
                guard let self = self else { return }
                self.updateFilteredItems(
                    searchText: text,
                    items: self.clipboardItems,
                    filter: filter,
                    resetSelection: true
                )
            }
            .store(in: &cancellables)

        // 列表内容变化：跟随当前搜索词/筛选重查，保持选中位置
        $clipboardItems
            .sink { [weak self] items in
                guard let self = self else { return }
                self.updateFilteredItems(
                    searchText: self.searchText,
                    items: items,
                    filter: self.selectedFilter,
                    resetSelection: false
                )
            }
            .store(in: &cancellables)
    }

    private func updateFilteredItems(searchText: String, items: [ClipboardItem], filter: FilterCategory, resetSelection: Bool) {
        filterQueue.async { [weak self] in
            guard let self = self else { return }
            let searched: [ClipboardItem]
            if searchText.isEmpty {
                searched = items
            } else {
                // 放宽 limit：类型筛选在查询之后内存内做，避免查询阶段提前截断漏项
                searched = ClipboardStorage.shared.searchLight(query: searchText, limit: 500)
            }
            let result = searched.filter { filter.matches($0.contentType) }
            DispatchQueue.main.async {
                self.filteredItems = result
                if resetSelection {
                    self.selectedIndex = 0
                } else if self.selectedIndex >= result.count {
                    self.selectedIndex = max(0, result.count - 1)
                }
            }
        }
    }
}
