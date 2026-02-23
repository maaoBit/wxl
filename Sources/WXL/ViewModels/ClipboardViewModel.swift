//
//  ClipboardViewModel.swift
//  WXL
//
//  ViewModel for managing clipboard state and operations
//

import SwiftUI
import Combine

class ClipboardViewModel: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var filteredItems: [ClipboardItem] = []
    @Published var searchText: String = ""
    @Published var selectedSourceApp: String?
    @Published var isLoading: Bool = false

    private var storage: ClipboardStorage
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.storage = ClipboardStorage.shared
        setupBindings()
    }

    private func setupBindings() {
        // 监听搜索文本变化
        $searchText
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .combineLatest($selectedSourceApp)
            .sink { [weak self] text, sourceApp in
                self?.filterItems(searchText: text, sourceApp: sourceApp)
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Operations

    func loadItems() {
        isLoading = true
        items = storage.loadAll()
        filterItems(searchText: searchText, sourceApp: selectedSourceApp)
        isLoading = false
    }

    func filterItems(searchText: String, sourceApp: String?) {
        if searchText.isEmpty && sourceApp == nil {
            filteredItems = items
        } else {
            filteredItems = storage.search(query: searchText, sourceApp: sourceApp)
        }

        // 确保选中索引有效
        if AppState.shared.selectedIndex >= filteredItems.count {
            AppState.shared.selectedIndex = max(0, filteredItems.count - 1)
        }
    }

    // MARK: - Item Operations

    func togglePin(_ item: ClipboardItem) {
        storage.togglePin(item.id)

        // 更新本地数据
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = items[index]
            updatedItem.isPinned.toggle()
            items[index] = updatedItem
        }

        // 重新过滤
        filterItems(searchText: searchText, sourceApp: selectedSourceApp)
    }

    func delete(_ item: ClipboardItem) {
        storage.delete(item.id)
        items.removeAll { $0.id == item.id }
        filterItems(searchText: searchText, sourceApp: selectedSourceApp)
    }

    func deleteAll() {
        for item in items where !item.isPinned {
            storage.delete(item.id)
        }
        items.removeAll { !$0.isPinned }
        filterItems(searchText: searchText, sourceApp: selectedSourceApp)
    }

    // MARK: - Source Apps

    func getUniqueSourceApps() -> [String] {
        return storage.getUniqueSourceApps()
    }

    // MARK: - Settings

    func getExpiryHours() -> Int {
        return UserDefaults.standard.integer(forKey: "expiryHours")
    }

    func setExpiryHours(_ hours: Int) {
        UserDefaults.standard.set(hours, forKey: "expiryHours")
    }

    func getMaxHistoryCount() -> Int {
        return UserDefaults.standard.integer(forKey: "maxHistoryCount")
    }

    func setMaxHistoryCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "maxHistoryCount")
    }
}
