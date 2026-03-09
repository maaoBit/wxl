//
//  ClipboardItem.swift
//  WXL
//
//  Data model for clipboard history items
//

import Foundation
import AppKit
import Vision

// MARK: - Content Type
enum ContentType: String, Codable, CaseIterable {
    case text = "text"
    case url = "url"
    case filePath = "filePath"
    case email = "email"
    case phoneNumber = "phoneNumber"
    case image = "image"
    case code = "code"

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .filePath: return "folder"
        case .email: return "envelope"
        case .phoneNumber: return "phone"
        case .image: return "photo"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Clipboard Item
struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let contentType: ContentType
    let sourceApp: String?
    let sourceAppBundle: String?
    let createdAt: Date
    var isPinned: Bool
    var expiresAt: Date?

    // 图片数据（如果有）
    var imageData: Data?
    var ocrText: String? // OCR 识别的文字
    var fileURLs: [String]? // 文件 URL 列表

    // 预览文本（截断显示）
    var previewText: String {
        let maxLen = 100
        if content.count > maxLen {
            return String(content.prefix(maxLen)) + "..."
        }
        return content
    }

    // 时间显示
    var timeAgo: String {
        return ClipboardItem.timeAgoFormatter.localizedString(for: createdAt, relativeTo: Date())
    }

    private static let timeAgoFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    init(
        content: String,
        contentType: ContentType = .text,
        sourceApp: String? = nil,
        sourceAppBundle: String? = nil,
        imageData: Data? = nil,
        fileURLs: [String]? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.contentType = contentType
        self.sourceApp = sourceApp
        self.sourceAppBundle = sourceAppBundle
        self.createdAt = Date()
        self.isPinned = false

        // 设置过期时间（24小时后）
        let expiryHours = UserDefaults.standard.integer(forKey: "expiryHours")
        self.expiresAt = Calendar.current.date(
            byAdding: .hour,
            value: expiryHours > 0 ? expiryHours : 24,
            to: Date()
        )

        self.imageData = imageData
        self.ocrText = nil
        self.fileURLs = fileURLs
    }

    /// 从数据库加载时使用的初始化器
    init(
        id: UUID,
        content: String,
        contentType: ContentType,
        sourceApp: String?,
        sourceAppBundle: String?,
        createdAt: Date,
        isPinned: Bool,
        expiresAt: Date?,
        imageData: Data?,
        ocrText: String?,
        fileURLs: [String]? = nil
    ) {
        self.id = id
        self.content = content
        self.contentType = contentType
        self.sourceApp = sourceApp
        self.sourceAppBundle = sourceAppBundle
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.expiresAt = expiresAt
        self.imageData = imageData
        self.ocrText = ocrText
        self.fileURLs = fileURLs
}
}

// MARK: - Content Type Detection
extension ClipboardItem {

    /// 检测内容类型
    static func detectContentType(_ content: String) -> ContentType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // URL
        if let url = URL(string: trimmed),
           let scheme = url.scheme,
           ["http", "https", "ftp"].contains(scheme.lowercased()) {
            return .url
        }

        // Email
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        if trimmed.range(of: emailPattern, options: .regularExpression) != nil {
            return .email
        }

        // Phone Number
        let phonePattern = "^[+]?[0-9\\s\\-\\(\\)]{7,20}$"
        if trimmed.range(of: phonePattern, options: .regularExpression) != nil {
            return .phoneNumber
        }

        // File Path (Unix or macOS style)
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return .filePath
        }

        // Code (简单检测：包含常见编程符号)
        let codeIndicators = ["{", "}", "=>", "->", "func ", "var ", "let ", "import ", "#include", "def ", "class "]
        for indicator in codeIndicators {
            if content.contains(indicator) {
                return .code
            }
        }

        return .text
    }
}

// MARK: - Array Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

    func safe(at index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
