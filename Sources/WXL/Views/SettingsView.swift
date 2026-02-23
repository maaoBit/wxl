//
//  SettingsView.swift
//  WXL
//
//  Settings and preferences view
//

import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct SettingsView: View {
    @AppStorage("expiryHours") private var expiryHours: Int = 24
    @AppStorage("maxHistoryCount") private var maxHistoryCount: Int = 500
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        TabView {
            GeneralSettingsView(
                expiryHours: $expiryHours,
                maxHistoryCount: $maxHistoryCount,
                launchAtLogin: $launchAtLogin
            )
            .tabItem {
                Label("通用", systemImage: "gearshape")
            }

            ShortcutsSettingsView()
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }

            AboutView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 400)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @Binding var expiryHours: Int
    @Binding var maxHistoryCount: Int
    @Binding var launchAtLogin: Bool

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
            }

            Section("启动") {
                Toggle("登录时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
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
        // 使用 SMAppService (macOS 13+) 或 ServiceManagement
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                try? service.register()
            } else {
                try? service.unregister()
            }
        }
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

            Text("版本 1.0.0")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            Text("使用 Liquid Glass UI 打造的优雅剪贴板管理工具")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
