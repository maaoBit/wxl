//
//  Logger.swift
//  WXL
//
//  统一的日志系统
//

import Foundation
import os.log

enum LoggerCategory {
    case database
    case clipboard
    case ui
    case general
}

struct Logger {
    private static let subsystem = "com.maoBit.wxl"

    private static var databaseLog: OSLog {
        OSLog(subsystem: subsystem, category: "Database")
    }

    private static var clipboardLog: OSLog {
        OSLog(subsystem: subsystem, category: "Clipboard")
    }

    private static var uiLog: OSLog {
        OSLog(subsystem: subsystem, category: "UI")
    }

    private static var generalLog: OSLog {
        OSLog(subsystem: subsystem, category: "General")
    }

    private static func osLog(for category: LoggerCategory) -> OSLog {
        switch category {
        case .database: return databaseLog
        case .clipboard: return clipboardLog
        case .ui: return uiLog
        case .general: return generalLog
        }
    }

    /// 记录日志
    /// - Parameters:
    ///   - message: 日志消息
    ///   - category: 日志类别
    ///   - type: 日志类型
    static func log(_ message: String, category: LoggerCategory, type: OSLogType = .info) {
        os_log("%{public}@", log: osLog(for: category), type: type, message)
    }

    /// 记录错误日志
    /// - Parameters:
    ///   - message: 错误消息
    ///   - category: 日志类别
    static func error(_ message: String, category: LoggerCategory) {
        self.log(message, category: category, type: .error)
    }

    /// 记录调试日志
    /// - Parameters:
    ///   - message: 调试消息
    ///   - category: 日志类别
    static func debug(_ message: String, category: LoggerCategory) {
        self.log(message, category: category, type: .debug)
    }
}
