//
//  AppExclusion.swift
//  WXL
//
//  Per-app capture exclusion (e.g. password managers)
//

import AppKit
import Foundation

/// 来源应用排除名单：名单内应用复制的内容不进入剪贴板历史
enum AppExclusion {

    private static let bundleIDsKey = "excludedAppBundleIDs"

    static var excludedBundleIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: bundleIDsKey) ?? [])
    }

    static func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID = bundleID, !bundleID.isEmpty else { return false }
        return excludedBundleIDs.contains(bundleID)
    }

    static func add(_ bundleID: String) {
        var ids = excludedBundleIDs
        ids.insert(bundleID)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: bundleIDsKey)
    }

    static func remove(_ bundleID: String) {
        var ids = excludedBundleIDs
        ids.remove(bundleID)
        UserDefaults.standard.set(Array(ids).sorted(), forKey: bundleIDsKey)
    }

    /// 显示用应用名；应用已卸载时回退为 bundle ID
    static func displayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url),
              let name = bundle.infoDictionary?["CFBundleName"] as? String else {
            return bundleID
        }
        return name
    }
}
