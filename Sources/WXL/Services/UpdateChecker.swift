//
//  UpdateChecker.swift
//  WXL
//
//  Checks GitHub Releases for new versions and installs updates automatically
//

import Foundation
import AppKit
import Combine

// MARK: - Settings Tab Request

/// 设置窗口的 tab 选择（用于跨模块通信）
enum SettingsTab: Hashable {
    case general
    case appearance
    case shortcuts
    case mcp
    case about
}

// MARK: - Update Status

/// 检查更新的状态
enum UpdateStatus: Equatable {
    case idle               // 空闲
    case checking           // 正在检查
    case upToDate           // 已是最新版
    case updateAvailable    // 发现新版本
    case downloading        // 正在下载
    case readyToInstall     // 下载完成，可以安装
    case failed             // 失败
}

// MARK: - Update Info

/// 从 GitHub Release 解析出的更新信息
struct UpdateInfo {
    let version: String         // "1.3.3"
    let tagName: String         // "v1.3.3"
    let dmgDownloadURL: URL?    // 匹配当前架构的 DMG 下载地址
    let htmlURL: URL            // release 页面地址（回退用）
    let releaseNotes: String?   // 发布说明
}

// MARK: - UpdateChecker

/// 版本更新检查与安装服务（单例）
final class UpdateChecker: NSObject, ObservableObject {

    static let shared = UpdateChecker()

    // MARK: - Published State

    @Published private(set) var status: UpdateStatus = .idle
    @Published private(set) var latestVersion: String?
    @Published private(set) var progress: Double = 0          // 0...1
    @Published private(set) var errorMessage: String?
    @Published private(set) var releaseNotes: String?

    /// 启动时是否已检查过（避免一个生命周期内重复弹窗）
    private(set) var hasCheckedOnLaunch: Bool = false

    /// 外部请求切换到的设置页（AppDelegate 触发“去更新”时设为 .about）
    @Published var requestedSettingsTab: SettingsTab? = nil

    /// 请求被消费后清除
    func consumeSettingsTabRequest() -> SettingsTab? {
        let tab = requestedSettingsTab
        requestedSettingsTab = nil
        return tab
    }

    // MARK: - Private

    /// GitHub API: 获取最新 release
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/maaoBit/wxl/releases/latest")!

    private var currentUpdateInfo: UpdateInfo?
    private var urlSession: URLSession?

    private override init() {
        super.init()
    }

    // MARK: - Current Version

    /// 已安装版本号（来自 Info.plist）
    var currentVersion: String {
        Bundle.main.currentVersion
    }

    // MARK: - Check for Updates

    /// 检查是否有新版本
    /// - Parameter isAutomatic: 是否为启动时的自动检查（影响日志）
    func checkForUpdates(isAutomatic: Bool = false) {
        // 自动检查时，若本生命周期已检查过，则跳过（避免重复弹窗）
        if isAutomatic && hasCheckedOnLaunch {
            return
        }

        DispatchQueue.main.async {
            self.status = .checking
            self.errorMessage = nil
        }

        Logger.log("Checking for updates (automatic=\(isAutomatic))...", category: .general)

        var request = URLRequest(url: latestReleaseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        // GitHub API 要求 User-Agent
        request.setValue("WXL-Updater", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let error = error {
                Logger.error("Update check failed: \(error.localizedDescription)", category: .general)
                self.handleCheckFailure(message: "网络请求失败：\(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Logger.error("Failed to parse release JSON", category: .general)
                self.handleCheckFailure(message: "无法解析服务器返回的数据")
                return
            }

            guard let info = self.parseRelease(json) else {
                Logger.error("Release JSON missing required fields", category: .general)
                self.handleCheckFailure(message: "无法获取版本信息")
                return
            }

            self.currentUpdateInfo = info
            self.evaluateUpdate(info: info, isAutomatic: isAutomatic)
        }.resume()
    }

    /// 解析 GitHub Release JSON 为 UpdateInfo
    private func parseRelease(_ json: [String: Any]) -> UpdateInfo? {
        guard let tagName = json["tag_name"] as? String else { return nil }

        let rawVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        let htmlURLString = (json["html_url"] as? String) ?? "https://github.com/maaoBit/wxl/releases"
        let htmlURL = URL(string: htmlURLString) ?? URL(string: "https://github.com/maaoBit/wxl/releases")!
        let notes = json["body"] as? String

        // 从 assets 匹配当前架构的 DMG
        var dmgURL: URL?
        if let assets = json["assets"] as? [[String: Any]] {
            let archSuffix = currentArchitectureSuffix
            // 优先匹配架构专属包：WXL-1.3.3-arm64.dmg
            if !archSuffix.isEmpty {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       name.hasSuffix("-\(archSuffix).dmg"),
                       let urlString = asset["browser_download_url"] as? String,
                       let url = URL(string: urlString) {
                        dmgURL = url
                        break
                    }
                }
            }
            // 回退：匹配任意 DMG（universal）
            if dmgURL == nil {
                for asset in assets {
                    if let name = asset["name"] as? String,
                       name.hasSuffix(".dmg"),
                       let urlString = asset["browser_download_url"] as? String,
                       let url = URL(string: urlString) {
                        dmgURL = url
                        break
                    }
                }
            }
        }

        return UpdateInfo(
            version: rawVersion,
            tagName: tagName,
            dmgDownloadURL: dmgURL,
            htmlURL: htmlURL,
            releaseNotes: notes
        )
    }

    /// 比较版本并更新状态
    private func evaluateUpdate(info: UpdateInfo, isAutomatic: Bool) {
        guard let current = Version(self.currentVersion),
              let latest = Version(info.version) else {
            Logger.error("Version parse failed: current=\(self.currentVersion), latest=\(info.version)", category: .general)
            self.handleCheckFailure(message: "版本号格式无法识别")
            return
        }

        Logger.log("Version compare: current=\(current.displayString), latest=\(latest.displayString)", category: .general)

        DispatchQueue.main.async {
            self.latestVersion = info.version
            self.releaseNotes = info.releaseNotes
            self.hasCheckedOnLaunch = true

            if latest > current {
                self.status = .updateAvailable
                Logger.log("New version available: \(info.version)", category: .general)
                if isAutomatic {
                    self.notifyUserOfUpdate(info: info)
                }
            } else {
                self.status = .upToDate
                Logger.log("App is up to date", category: .general)
            }
        }
    }

    private func handleCheckFailure(message: String) {
        DispatchQueue.main.async {
            self.status = .failed
            self.errorMessage = message
        }
    }

    // MARK: - Auto-check notification

    /// 启动自动检查发现新版本时，通过菜单栏图标提示用户（非阻塞）
    private func notifyUserOfUpdate(info: UpdateInfo) {
        // 广播通知，AppDelegate 收到后在菜单栏图标上加红点 badge
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .updateAvailableBadge,
                object: nil,
                userInfo: ["version": info.version]
            )
            Logger.log("Notified user of new version via status bar badge", category: .general)
        }
    }

    // MARK: - Download & Install

    /// 下载并安装最新版本
    func downloadAndInstall() {
        guard let info = currentUpdateInfo else {
            DispatchQueue.main.async {
                self.status = .failed
                self.errorMessage = "没有可用的更新信息，请先检查更新"
            }
            return
        }

        guard let dmgURL = info.dmgDownloadURL else {
            // 没有匹配的 DMG，回退到浏览器打开 release 页面
            Logger.log("No matching DMG asset, opening release page", category: .general)
            NSWorkspace.shared.open(info.htmlURL)
            return
        }

        DispatchQueue.main.async {
            self.status = .downloading
            self.progress = 0
            self.errorMessage = nil
        }

        Logger.log("Downloading DMG from \(dmgURL.absoluteString)", category: .general)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.urlSession = session

        let task = session.downloadTask(with: dmgURL) { [weak self] tempURL, _, error in
            guard let self = self else { return }

            if let error = error {
                Logger.error("Download failed: \(error.localizedDescription)", category: .general)
                DispatchQueue.main.async {
                    self.status = .failed
                    self.errorMessage = "下载失败：\(error.localizedDescription)"
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    self.status = .failed
                    self.errorMessage = "下载文件丢失"
                }
                return
            }

            // 把临时文件移动到稳定位置
            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("WXL-\(info.version).dmg")
            try? FileManager.default.removeItem(at: destURL)

            do {
                try FileManager.default.moveItem(at: tempURL, to: destURL)
            } catch {
                DispatchQueue.main.async {
                    self.status = .failed
                    self.errorMessage = "保存下载文件失败：\(error.localizedDescription)"
                }
                return
            }

            Logger.log("Download complete: \(destURL.path)", category: .general)

            DispatchQueue.main.async {
                self.status = .readyToInstall
                self.promptToInstall(dmgPath: destURL.path, info: info)
            }
        }
        task.resume()
    }

    /// 弹窗询问用户是否立即安装
    private func promptToInstall(dmgPath: String, info: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "下载完成"
        alert.informativeText = "v\(info.version) 已下载完成，是否立即安装？\n安装过程会退出当前应用并重新启动。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "立即安装")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            performInstall(dmgPath: dmgPath)
        }
    }

    /// 执行安装：用 detached shell 脚本在 App 退出后覆盖 .app 并重启
    private func performInstall(dmgPath: String) {
        // 动态解析安装目标：使用当前 .app 的实际位置，而非硬编码 /Applications
        let currentAppPath = Bundle.main.bundlePath
        let appFileName = (currentAppPath as NSString).lastPathComponent  // 通常为 "WXL.app"
        let appPath = currentAppPath

        // 写一个临时脚本，等当前进程退出后再执行覆盖+重启
        // 使用位置参数 $1=挂载点 $2=dmg路径 $3=app路径 $4=app文件名，避免字符串拼接的特殊字符问题
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("wxl_update.sh")
        let script = """
        #!/bin/bash
        set -u
        MOUNT_POINT="$1"
        DMG_PATH="$2"
        APP_PATH="$3"
        APP_NAME="$4"

        # 等待当前 WXL 进程退出（最多 30 秒）
        for i in $(seq 1 30); do
            if ! pgrep -x WXL > /dev/null; then
                break
            fi
            sleep 1
        done
        sleep 1

        # 清理可能残留的挂载点目录
        umount "$MOUNT_POINT" 2>/dev/null
        rm -rf "$MOUNT_POINT"
        mkdir -p "$MOUNT_POINT"

        # 挂载 DMG 到固定挂载点（-mountpoint 避免依赖输出格式解析）
        if ! hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint "$MOUNT_POINT"; then
            osascript -e 'display notification "挂载安装包失败" with title "WXL 更新失败"'
            exit 1
        fi

        # 复制新 .app 覆盖旧的
        rm -rf "$APP_PATH"
        if ! cp -R "$MOUNT_POINT/$APP_NAME" "$APP_PATH"; then
            osascript -e 'display notification "复制应用失败" with title "WXL 更新失败"'
            hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
            exit 1
        fi

        # 清除 quarantine 扩展属性（避免 Gatekeeper 因无公证拦截 ad-hoc 签名的 .app）
        xattr -cr "$APP_PATH" 2>/dev/null

        # 卸载 DMG 并清理
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
        rm -rf "$MOUNT_POINT"
        rm -f "$DMG_PATH"

        # 重启应用
        open "$APP_PATH"
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        } catch {
            Logger.error("Failed to write install script: \(error.localizedDescription)", category: .general)
            DispatchQueue.main.async {
                self.status = .failed
                self.errorMessage = "无法创建安装脚本：\(error.localizedDescription)"
            }
            return
        }

        // 挂载点用 PID 保证唯一
        let mountPoint = "/tmp/wxl_update_mount_\(getpid())"
        Logger.log("Launching install script (appPath=\(appPath), mount=\(mountPoint)), then terminating app", category: .general)

        // 启动 detached 脚本，参数通过 argv 传入避免特殊字符问题
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            scriptURL.path,
            mountPoint,
            dmgPath,
            appPath,
            appFileName
        ]
        process.qualityOfService = .utility
        do {
            try process.run()
        } catch {
            Logger.error("Failed to launch install script: \(error.localizedDescription)", category: .general)
            DispatchQueue.main.async {
                self.status = .failed
                self.errorMessage = "无法启动安装进程：\(error.localizedDescription)"
            }
            return
        }

        // 退出当前应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    /// 重置状态（UI 复位用）
    func reset() {
        DispatchQueue.main.async {
            self.status = .idle
            self.errorMessage = nil
            self.progress = 0
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension UpdateChecker: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let ratio = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progress = ratio
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // 由 downloadTask(with:) 的 completion handler 处理
    }
}

// MARK: - Notification Name

extension Notification.Name {
    /// 发现新版本，菜单栏图标应显示红点 badge
    static let updateAvailableBadge = Notification.Name("WXLUpdateAvailableBadge")

    /// 请求打开设置窗口的“关于”页（用于启动检查发现新版本后引导用户）
    static let openAboutSettings = Notification.Name("WXLOpenAboutSettings")
}
