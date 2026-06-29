//
//  Version.swift
//  WXL
//
//  Semantic version parsing and comparison utilities for update checking
//

import Foundation

// MARK: - Version

/// Represents a semantic version (major.minor.patch) for comparison
struct Version: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    /// Parses a version string like "1.3.2" or "v1.3.2" into a Version.
    /// Returns nil if the string cannot be parsed.
    init?(_ raw: String) {
        // 去掉可能的前缀（如 "v1.3.2" 的 "v"）和首尾空白
        var cleaned = raw.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("v") || cleaned.hasPrefix("V") {
            cleaned.removeFirst()
        }

        let parts = cleaned.split(separator: ".").map { String($0) }
        guard parts.count >= 1, let major = Int(parts[0]) else { return nil }

        self.major = major
        self.minor = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        self.patch = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
    }

    var displayString: String {
        "\(major).\(minor).\(patch)"
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    static func == (lhs: Version, rhs: Version) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

// MARK: - Bundle Extension

extension Bundle {
    /// 当前安装版本号，从 Info.plist 的 CFBundleShortVersionString 读取
    var currentVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}

// MARK: - Architecture Helper

/// 返回当前运行架构对应的 DMG 文件名后缀（用于匹配 release 资产）
var currentArchitectureSuffix: String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x86_64"
    #else
    return ""
    #endif
}
