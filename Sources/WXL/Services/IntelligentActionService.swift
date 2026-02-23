//
//  IntelligentActionService.swift
//  WXL
//
//  Intelligent actions for different content types
//

import Foundation
import AppKit
import CoreServices

class IntelligentActionService {
    static let shared = IntelligentActionService()

    /// 测试时设置为 true，避免打开实际应用
    var simulationMode = false

    /// 模拟模式下记录最后执行的操作（用于测试验证）
    var lastSimulatedAction: (type: String, content: String)?

    private init() {}

    // MARK: - URL Actions

    /// 在默认浏览器中打开 URL
    func openURL(_ urlString: String) {
        // 清理 URL 字符串
        var cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 如果没有 scheme，添加 https
        if !cleanedURL.hasPrefix("http://") && !cleanedURL.hasPrefix("https://") {
            cleanedURL = "https://" + cleanedURL
        }

        guard let url = URL(string: cleanedURL) else { return }

        if simulationMode {
            lastSimulatedAction = ("openURL", url.absoluteString)
            return
        }

        NSWorkspace.shared.open(url)
    }

    /// 在指定浏览器中打开 URL
    func openURL(_ urlString: String, in browser: String) {
        var cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanedURL.hasPrefix("http://") && !cleanedURL.hasPrefix("https://") {
            cleanedURL = "https://" + cleanedURL
        }

        guard let url = URL(string: cleanedURL) else { return }

        if simulationMode {
            lastSimulatedAction = ("openURL", "\(url.absoluteString) in \(browser)")
            return
        }

        // 获取指定浏览器的 bundle ID
        let browserBundleIDs: [String: String] = [
            "safari": "com.apple.Safari",
            "chrome": "com.google.Chrome",
            "firefox": "org.mozilla.firefox",
            "edge": "com.microsoft.edgemac",
            "arc": "company.thebrowser.Browser"
        ]

        if let bundleID = browserBundleIDs[browser.lowercased()],
           let browserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: browserURL, configuration: configuration)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - File Path Actions

    /// 在 Finder 中显示文件
    func revealInFinder(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath

        if simulationMode {
            lastSimulatedAction = ("revealInFinder", expandedPath)
            return
        }

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            // 文件不存在，尝试打开父目录
            let parentPath = (expandedPath as NSString).deletingLastPathComponent
            if FileManager.default.fileExists(atPath: parentPath) {
                NSWorkspace.shared.open(URL(fileURLWithPath: parentPath))
            }
            return
        }

        let url = URL(fileURLWithPath: expandedPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// 用默认应用打开文件
    func openFile(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath

        if simulationMode {
            lastSimulatedAction = ("openFile", expandedPath)
            return
        }

        guard FileManager.default.fileExists(atPath: expandedPath) else { return }

        let url = URL(fileURLWithPath: expandedPath)
        NSWorkspace.shared.open(url)
    }

    /// 复制文件路径
    func copyFilePath(_ path: String) {
        let expandedPath = (path as NSString).expandingTildeInPath
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(expandedPath, forType: .string)
    }

    // MARK: - Email Actions

    /// 打开邮件客户端
    func openEmail(_ email: String) {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "mailto:\(cleaned)") else { return }

        if simulationMode {
            lastSimulatedAction = ("openEmail", cleaned)
            return
        }

        NSWorkspace.shared.open(url)
    }

    /// 复制邮箱地址
    func copyEmail(_ email: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(email.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
    }

    // MARK: - Phone Actions

    /// 打开 FaceTime
    func openFaceTime(_ phone: String) {
        let cleaned = cleanPhoneNumber(phone)
        guard let url = URL(string: "facetime://\(cleaned)") else { return }

        if simulationMode {
            lastSimulatedAction = ("openFaceTime", cleaned)
            return
        }

        NSWorkspace.shared.open(url)
    }

    /// 打开 FaceTime 音频
    func openFaceTimeAudio(_ phone: String) {
        let cleaned = cleanPhoneNumber(phone)
        guard let url = URL(string: "facetime-audio://\(cleaned)") else { return }

        if simulationMode {
            lastSimulatedAction = ("openFaceTimeAudio", cleaned)
            return
        }

        NSWorkspace.shared.open(url)
    }

    /// 复制电话号码
    func copyPhone(_ phone: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(phone, forType: .string)
    }

    // MARK: - Helpers

    private func cleanPhoneNumber(_ phone: String) -> String {
        return phone.replacingOccurrences(
            of: "[\\s\\-\\(\\)\\+]",
            with: "",
            options: .regularExpression
        )
    }
}

// MARK: - Action Type
enum ContentAction: String, CaseIterable {
    case openURL = "在浏览器中打开"
    case revealInFinder = "在 Finder 中显示"
    case openFile = "打开文件"
    case sendEmail = "发送邮件"
    case faceTime = "FaceTime"
    case faceTimeAudio = "FaceTime 音频"
    case copyPath = "复制路径"

    var icon: String {
        switch self {
        case .openURL: return "safari"
        case .revealInFinder: return "folder"
        case .openFile: return "doc"
        case .sendEmail: return "envelope"
        case .faceTime: return "video"
        case .faceTimeAudio: return "phone"
        case .copyPath: return "doc.on.clipboard"
        }
    }

    var keyboardShortcut: String {
        switch self {
        case .openURL: return "⌘↵"
        case .revealInFinder: return "⌘↵"
        case .openFile: return "⌘O"
        case .sendEmail: return "⌘↵"
        case .faceTime: return "⌘↵"
        case .faceTimeAudio: return "⌘⇧↵"
        case .copyPath: return "⌥⌘C"
        }
    }
}
