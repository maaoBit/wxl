//
//  PanelView.swift
//  WXL
//
//  Main panel view with Liquid Glass UI
//

import SwiftUI
import Combine

struct PanelView: View {
    @StateObject private var appState = AppState.shared
    @FocusState private var isSearchFocused: Bool

    // MARK: - Pagination State
    @State private var loadedCount = 50
    @State private var isLoadingMore = false
    private let pageSize = 50
    private let searchMaxCount = 200

    private var displayedItems: [ClipboardItem] {
        let limit = appState.searchText.isEmpty ? loadedCount : searchMaxCount
        return Array(appState.filteredItems.prefix(limit))
    }

    var body: some View {
        LiquidGlassContainer {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar

                // 类型筛选
                filterChips

                // 主内容区域 - 左右分栏
                if appState.filteredItems.isEmpty {
                    emptyState
                } else {
                    mainContent
                }

                // 状态栏
                statusBar
            }
            .padding(16)
        }
        .frame(width: 700, height: 450)
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .onChange(of: appState.selectedIndex) { _, newIndex in
            // 确保索引有效
            if newIndex >= appState.filteredItems.count && !appState.filteredItems.isEmpty {
                appState.selectedIndex = appState.filteredItems.count - 1
            }
        }
        .onChange(of: appState.searchText) { _, _ in
            loadedCount = pageSize
        }
        .onChange(of: appState.selectedFilter) { _, _ in
            loadedCount = pageSize
        }
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(FilterCategory.allCases, id: \.self) { category in
                let isSelected = appState.selectedFilter == category
                Button {
                    appState.selectedFilter = category
                } label: {
                    Text(category.label)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(isSelected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Main Content (左右分栏)
    private var mainContent: some View {
        HStack(spacing: 12) {
            // 左侧：紧凑列表
            compactItemList

            // 分隔线
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1)

            // 右侧：详细内容预览
            detailPreview
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            TextField("搜索剪贴板...", text: $appState.searchText)
                .font(.system(size: 14))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    pasteSelected()
                }

            Spacer()

            if !appState.searchText.isEmpty {
                Button(action: { appState.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 12)
    }

    // MARK: - Compact Item List (左侧紧凑列表)
    private var compactItemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                        CompactClipboardItemRow(
                            item: item,
                            isSelected: index == appState.selectedIndex,
                            onSelect: {
                                appState.selectedIndex = index
                            },
                            onPaste: {
                                appState.selectedIndex = index
                                pasteSelected()
                            },
                            onPin: {
                                togglePin(item)
                            },
                            onDelete: {
                                deleteItem(item)
                            },
                            onCopy: {
                                copyItem(item)
                            },
                            openAction: getAction(for: item)
                        )
                        .id(item.id)
                    }

                    if displayedItems.count < appState.filteredItems.count {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .task { await loadMoreIfNeeded() }
                    }
                }
                .onChange(of: appState.selectedIndex) { _, newIndex in
                    // 滚动到选中项
                    if let item = appState.filteredItems.safe(at: newIndex) {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Detail Preview (右侧详细内容)
    private var detailPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item = appState.selectedItem {
                // 标题栏
                HStack {
                    Text(item.previewText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    // 操作按钮
                    HStack(spacing: 8) {
                        Button(action: { togglePin(item) }) {
                            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 11))
                                .foregroundColor(item.isPinned ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)

                        if let action = getAction(for: item) {
                            Button(action: action) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { deleteItem(item) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 分隔线
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 1)

                // 完整内容
                ScrollView {
                    // 轻量级加载的列表中 imageData 可能为 nil，按需从数据库加载
                    let imageData = item.imageData ?? ClipboardStorage.shared.loadImageData(item.id)
                    if item.contentType == .image, let imageData = imageData, let nsImage = NSImage(data: imageData) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 图片
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)

                            // OCR 识别结果
                            if let ocrText = item.ocrText, !ocrText.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text.viewfinder")
                                            .font(.system(size: 10))
                                        Text("OCR 识别结果")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(.secondary)

                                    Text(ocrText)
                                        .font(.system(size: 11))
                                        .foregroundColor(.primary.opacity(0.8))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.primary.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            } else {
                                // OCR 为空时显示提示
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text.viewfinder")
                                        .font(.system(size: 10))
                                    Text("OCR: 暂无识别结果")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(item.detailLines.indices, id: \.self) { index in
                                Text(item.detailLines[index])
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.primary.opacity(0.9))
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .scrollIndicators(.visible)

                // 底部信息
                HStack(spacing: 12) {
                    // 来源应用
                    if let app = item.sourceApp {
                        HStack(spacing: 4) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 9))
                            Text(app)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary.opacity(0.7))
                    }

                    // 时间
                    Text(item.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))

                    Spacer()

                    // 字符统计（文件条目显示文件数）
                    Text(item.footerStatText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            } else {
                // 未选中状态
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("选择一项查看详情")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text(appState.searchText.isEmpty ? "暂无剪贴板记录" : "未找到匹配内容")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)

            if appState.searchText.isEmpty {
                Text("复制内容后将自动出现在这里")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            Text("\(appState.filteredItems.count) 条记录")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 16) {
                shortcutHint("↑↓", "导航")
                shortcutHint("↵", "粘贴")
                shortcutHint("⌘↵", "打开")
                shortcutHint("⌘P", "置顶")
                shortcutHint("⌘D", "删除")
                shortcutHint("Esc", "关闭")
            }
        }
        .padding(.top, 12)
    }

    private func shortcutHint(_ key: String, _ action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary.opacity(0.7))
            Text(action)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadMoreIfNeeded() async {
        guard !isLoadingMore else { return }
        guard loadedCount < appState.filteredItems.count else { return }

        isLoadingMore = true
        try? await Task.sleep(nanoseconds: 150_000_000)
        loadedCount = min(loadedCount + pageSize, appState.filteredItems.count)
        isLoadingMore = false
    }

    private func getAction(for item: ClipboardItem) -> (() -> Void)? {
        // 统一走 IntelligentActionService（补 scheme、trim、不存在时回退父目录等）
        let service = IntelligentActionService.shared
        switch item.contentType {
        case .url:
            return { service.openURL(item.content) }
        case .filePath:
            // 使用 fileURLs 中的完整路径，而不是 content（只是文件名）
            if let filePath = item.fileURLs?.first {
                return { service.revealInFinder(filePath) }
            }
            return nil
        case .email:
            return { service.openEmail(item.content) }
        case .phoneNumber:
            return { service.openFaceTime(item.content) }
        default:
            return nil
        }
    }

    private func pasteSelected() {
        guard let item = appState.selectedItem else { return }

        // 刷新时间戳并移到所在分区（置顶区/普通区）首位
        // 内存内重排序，避免在主线程加载全部数据（含 imageData）导致卡顿
        ClipboardStorage.shared.refreshTimestamp(item.id)
        appState.clipboardItems = ClipboardItem.reorderAfterUse(appState.clipboardItems, usedItemId: item.id)
        appState.selectedIndex = 0

        // 通知监听器忽略即将发生的剪贴板变化
        ClipboardMonitor.shared.setIgnoreNextChange()

        copyToClipboard(item)
        dismissPanel()
        NSApplication.shared.hide(nil)
    }

    private func togglePin(_ item: ClipboardItem) {
        ClipboardStorage.shared.togglePin(item.id)
        // 重新加载
        appState.clipboardItems = ClipboardStorage.shared.loadAll()
    }

    private func deleteItem(_ item: ClipboardItem) {
        ClipboardStorage.shared.delete(item.id)
        // 重新加载
        appState.clipboardItems = ClipboardStorage.shared.loadAll()
        // 调整索引
        if appState.selectedIndex >= appState.clipboardItems.count {
            appState.selectedIndex = max(0, appState.clipboardItems.count - 1)
        }
    }

    private func dismissPanel() {
        NSApplication.shared.keyWindow?.orderOut(nil)
    }

    private func copyToClipboard(_ item: ClipboardItem) {
        Logger.debug("copyToClipboard: contentType=\(item.contentType), fileURLs=\(item.fileURLs ?? [])", category: .clipboard)

        // 轻量级加载的列表中 imageData 可能为 nil，按需从数据库加载
        let imageData: Data? = item.contentType == .image
            ? (item.imageData ?? ClipboardStorage.shared.loadImageData(item.id))
            : nil

        ClipboardWriter.write(item, to: NSPasteboard.general, imageData: imageData)
    }

    /// 右键菜单「复制内容」：仅写回剪贴板，不触发粘贴流程（不忽略监听，
    /// 监听器会按既有语义刷新该项时间戳）
    private func copyItem(_ item: ClipboardItem) {
        let imageData: Data? = item.contentType == .image
            ? (item.imageData ?? ClipboardStorage.shared.loadImageData(item.id))
            : nil
        ClipboardWriter.write(item, to: NSPasteboard.general, imageData: imageData)
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
