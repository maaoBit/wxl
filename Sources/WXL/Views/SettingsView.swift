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

            AppearanceSettingsView()
                .tabItem {
                    Label("外观", systemImage: "paintbrush")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
                }

            MCPSettingsView()
                .tabItem {
                    Label("MCP", systemImage: "network")
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

// MARK: - MCP Settings
struct MCPSettingsView: View {
    @AppStorage("mcpEnabled") private var mcpEnabled: Bool = true
    @AppStorage("mcpPort") private var mcpPort: Int = 9527
    @State private var serverStatus: String = "未知"

    let portOptions = [9527, 9528, 9529, 9530]

    var body: some View {
        Form {
            Section("服务器设置") {
                Toggle("启用 MCP 服务器", isOn: $mcpEnabled)
                    .onChange(of: mcpEnabled) { _, newValue in
                        if newValue {
                            MCPServer.shared.start()
                        } else {
                            MCPServer.shared.stop()
                        }
                        updateServerStatus()
                    }

                LabeledContent("端口") {
                    Picker("", selection: $mcpPort) {
                        ForEach(portOptions, id: \.self) { port in
                            Text("\(port)").tag(port)
                        }
                    }
                    .frame(width: 100)
                    .onChange(of: mcpPort) { _, _ in
                        MCPServer.shared.restart()
                        updateServerStatus()
                    }
                }

                LabeledContent("状态") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(serverStatus == "运行中" ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(serverStatus)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Claude Code 配置") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("在 Claude Code 中运行以下命令添加 MCP 服务器：")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("claude mcp add --transport http wxl http://127.0.0.1:\(mcpPort)/mcp")
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .textSelection(.enabled)
                }
            }

            Section("可用工具") {
                VStack(alignment: .leading, spacing: 8) {
                    toolRow("get_clipboard_history", "获取剪贴板历史记录")
                    toolRow("search_clipboard", "搜索剪贴板内容")
                    toolRow("generate_note", "从剪贴板项目生成笔记")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            updateServerStatus()
        }
    }

    private func toolRow(_ name: String, _ description: String) -> some View {
        HStack {
            Text(name)
                .font(.system(.body, design: .monospaced))
            Spacer()
            Text(description)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func updateServerStatus() {
        DispatchQueue.global(qos: .utility).async {
            // 检查端口是否在监听
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            task.arguments = ["-i", ":\(mcpPort)"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            let status: String
            do {
                try task.run()
                task.waitUntilExit()
                status = task.terminationStatus == 0 ? "运行中" : "已停止"
            } catch {
                status = "未知"
            }

            DispatchQueue.main.async {
                serverStatus = status
            }
        }
    }
}
