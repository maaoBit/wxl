//
//  SettingsView.swift
//  WXL
//
//  Settings and preferences view
//

import SwiftUI
import KeyboardShortcuts
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("expiryHours") private var expiryHours: Int = 24
    @AppStorage("maxHistoryCount") private var maxHistoryCount: Int = 500
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                expiryHours: $expiryHours,
                maxHistoryCount: $maxHistoryCount,
                launchAtLogin: $launchAtLogin
            )
            .tag(SettingsTab.general)
            .tabItem {
                Label("通用", systemImage: "gearshape")
            }

            AppearanceSettingsView()
                .tag(SettingsTab.appearance)
                .tabItem {
                    Label("外观", systemImage: "paintbrush")
                }

            ShortcutsSettingsView()
                .tag(SettingsTab.shortcuts)
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }

            AboutView()
                .tag(SettingsTab.about)
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 400)
        .onAppear {
            // 若 UpdateChecker 请求切换到某页（如发现新版本后引导到“关于”）
            if let requested = updateChecker.consumeSettingsTabRequest() {
                selectedTab = requested
            }
        }
        .onChange(of: updateChecker.requestedSettingsTab) { _, newValue in
            if let tab = newValue {
                selectedTab = tab
                _ = updateChecker.consumeSettingsTabRequest()
            }
        }
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @Binding var expiryHours: Int
    @Binding var maxHistoryCount: Int
    @Binding var launchAtLogin: Bool
    @AppStorage("checkForUpdatesOnLaunch") private var checkForUpdatesOnLaunch: Bool = true
    @AppStorage("autoPasteAfterSelection") private var autoPasteAfterSelection = false
    @State private var showClearConfirmation = false
    @State private var excludedApps: [String] = []

    let expiryOptions = [6, 12, 24, 48, 72, 168] // hours
    let countOptions = [100, 200, 500, 1000, 2000]

    var body: some View {
        Form {
            Section("历史记录") {
                LabeledContent("自动清理时间") {
                    Picker("", selection: $expiryHours) {
                        ForEach(expiryOptions, id: \.self) { hours in
                            Text(formatExpiry(hours)).tag(hours)
                        }
                    }
                    .frame(width: 120)
                }

                LabeledContent("最大历史条数") {
                    Picker("", selection: $maxHistoryCount) {
                        ForEach(countOptions, id: \.self) { count in
                            Text("\(count) 条").tag(count)
                        }
                    }
                    .frame(width: 120)
                }
                .onChange(of: maxHistoryCount) { _, _ in
                    // 立即按新上限清理，而不是等下一次保存时才生效
                    ClipboardStorage.shared.limitHistoryCount()
                }
            }

            Section("粘贴") {
                Toggle("选中后自动粘贴到当前应用", isOn: $autoPasteAfterSelection)
                if autoPasteAfterSelection {
                    if AutoPasteService.isTrusted {
                        Text("已授权：选中条目后会自动向此前的前台应用发送 ⌘V")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("需要「辅助功能」权限才能模拟按键")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("打开设置") {
                                if let url = AutoPasteService.accessibilitySettingsURL {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("隐私") {
                if excludedApps.isEmpty {
                    Text("可将某些应用（如密码管理器）排除在剪贴板历史之外")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        HStack {
                            Text(AppExclusion.displayName(for: bundleID))
                            Spacer()
                            Button {
                                AppExclusion.remove(bundleID)
                                refreshExcluded()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button {
                    addExcludedApp()
                } label: {
                    Label("添加应用…", systemImage: "plus")
                }
            }

            Section("启动") {
                Toggle("登录时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Toggle("启动时自动检查更新", isOn: $checkForUpdatesOnLaunch)
            }

            Section("数据") {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("清空全部历史", systemImage: "trash")
                }
                .confirmationDialog(
                    "确定清空全部历史记录？",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("清空（含置顶项）", role: .destructive) {
                        ClipboardStorage.shared.deleteAll()
                        AppState.shared.clipboardItems = []
                    }
                } message: {
                    Text("所有剪贴板历史（包括置顶项）将被永久删除，此操作不可恢复。")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func formatExpiry(_ hours: Int) -> String {
        if hours < 24 {
            return "\(hours) 小时"
        } else {
            let days = hours / 24
            return "\(days) 天"
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                try? service.register()
            } else {
                try? service.unregister()
            }
        }
    }

    private func refreshExcluded() {
        excludedApps = Array(AppExclusion.excludedBundleIDs).sorted()
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                    AppExclusion.add(bundleID)
                }
            }
            refreshExcluded()
        }
    }
}

// MARK: - Appearance Settings
struct AppearanceSettingsView: View {
    @AppStorage("glassOpacity") private var glassOpacity: Double = 0.85
    
    var body: some View {
        Form {
            Section("玻璃效果") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("背景透明度")
                        Spacer()
                        Text("\(Int(glassOpacity * 100))%")
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    Slider(value: $glassOpacity, in: 0.3...1.0, step: 0.05)
                        .labelsHidden()
                    
                    Text("调低透明度可使窗口更透明，调高则更实心。在白色背景下建议调高透明度以提高文字可读性。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Settings
struct ShortcutsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("快捷键设置")
                .font(.headline)
            
            // 全局快捷键（可自定义）
            VStack(alignment: .leading, spacing: 12) {
                Text("全局快捷键")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("显示/隐藏面板")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .togglePanel) {
                        Text("点击录制")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 180)
                }
            }
            
            Divider()
            
            // 面板内快捷键（不可自定义）
            VStack(alignment: .leading, spacing: 12) {
                Text("面板内快捷键（固定）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                shortcutRow("Esc", "关闭面板")
                shortcutRow("↑ / ↓", "上下选择项目")
                shortcutRow("Enter", "粘贴选中内容")
                shortcutRow("⌘ + Enter", "执行智能动作")
                shortcutRow("⌘ + P", "置顶/取消置顶")
                shortcutRow("⌘ + D", "删除选中内容")
                shortcutRow("输入字符", "实时搜索")
                
                Text("注：面板内快捷键为固定设置，不可自定义")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func shortcutRow(_ key: String, _ action: String) -> some View {
        HStack {
            Text(action)
                .font(.body)
            Spacer()
            Text(key)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - About View
struct AboutView: View {
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clipboard.on.clipboard")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("WXL")
                .font(.system(size: 24, weight: .bold))

            Text("macOS 剪贴板历史管理器")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text(updateChecker.currentVersion.isEmpty ? AppConstants.displayVersion : "v\(updateChecker.currentVersion)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            // 更新检查区块
            updateSection

            Spacer()

            Text("使用 Liquid Glass UI 打造的优雅剪贴板管理工具")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Update Section

    @ViewBuilder
    private var updateSection: some View {
        switch updateChecker.status {
        case .idle:
            Button(action: { updateChecker.checkForUpdates() }) {
                Label("检查更新", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)

        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("正在检查...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case .upToDate:
            VStack(spacing: 8) {
                Label("已是最新版本", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                Button(action: { updateChecker.checkForUpdates() }) {
                    Text("再次检查")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
            }

        case .updateAvailable:
            VStack(spacing: 8) {
                Label("发现新版本 v\(updateChecker.latestVersion ?? "")", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)

                Button(action: { updateChecker.downloadAndInstall() }) {
                    Label("下载并安装", systemImage: "arrow.down.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)

                Button(action: { updateChecker.reset() }) {
                    Text("忽略")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

        case .downloading:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProgressView(value: updateChecker.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 160)
                    Text("\(Int(updateChecker.progress * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Text("正在下载 v\(updateChecker.latestVersion ?? "")...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

        case .readyToInstall:
            // 安装提示已由弹窗处理，这里显示一个占位
            Label("准备安装...", systemImage: "gear")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

        case .failed:
            VStack(spacing: 8) {
                Label(updateChecker.errorMessage ?? "检查更新失败", systemImage: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                Button(action: { updateChecker.checkForUpdates() }) {
                    Text("重试")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
