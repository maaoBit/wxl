//
//  ClipboardStorage.swift
//  WXL
//
//  Handles persistent storage of clipboard history
//

import Foundation
import SQLite
import os.log
import CryptoKit

class ClipboardStorage {
    static let shared = ClipboardStorage()

    private var db: Connection?
    private let itemsTable = Table("clipboard_items")
    private let idCol = Expression<String>("id")
    private let contentCol = Expression<String>("content")
    private let contentHashCol = Expression<String>("contentHash")
    private let contentTypeCol = Expression<String>("contentType")
    private let sourceAppCol = Expression<String?>("sourceApp")
    private let sourceAppBundleCol = Expression<String?>("sourceAppBundle")
    private let createdAtCol = Expression<Double>("createdAt")
    private let isPinnedCol = Expression<Bool>("isPinned")
    private let expiresAtCol = Expression<Double?>("expiresAt")
    private let imageDataCol = Expression<Data?>("imageData")
    private let ocrTextCol = Expression<String?>("ocrText")
    private let queue = DispatchQueue(label: "com.wxl.clipboardstorage", qos: .userInitiated)

    /// 用于测试的标识
    private let isTestMode: Bool

    /// 默认初始化器（生产环境使用）
    private init() {
        self.isTestMode = false
        setupDatabase(at: nil)
    }

    /// 自定义数据库路径的初始化器（测试环境使用）
    /// - Parameter databasePath: 数据库文件路径，传 nil 使用默认路径
    init(databasePath: String?) {
        self.isTestMode = true
        setupDatabase(at: databasePath)
    }

    private func setupDatabase(at customPath: String?) {
        do {
            let dbPath: String

            if let customPath = customPath {
                // 使用自定义路径（测试模式）
                dbPath = customPath
            } else {
                // 使用默认路径（生产模式）
                let fileManager = FileManager.default
                let appSupportURL = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )

                let dbURL = appSupportURL.appendingPathComponent("WXL/clipboard.db")
                try fileManager.createDirectory(at: dbURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                dbPath = dbURL.path
            }

            db = try Connection(dbPath)

            // 创建表（如果不存在）
            try db?.run(itemsTable.create(ifNotExists: true) { t in
                t.column(idCol, primaryKey: true)
                t.column(contentCol)
                t.column(contentHashCol)
                t.column(contentTypeCol)
                t.column(sourceAppCol)
                t.column(sourceAppBundleCol)
                t.column(createdAtCol)
                t.column(isPinnedCol, defaultValue: false)
                t.column(expiresAtCol)
                t.column(imageDataCol)
                t.column(ocrTextCol)
            })

            // 检查并添加 contentHash 列（如果表已存在但缺少该列）
            // 尝试查询 contentHash 列来检测是否存在
            var hasContentHash = false
            do {
                let testQuery = itemsTable.select(contentHashCol).limit(1)
                _ = try db?.pluck(testQuery)
                hasContentHash = true
            } catch {
                hasContentHash = false
            }

            if !hasContentHash {
                Logger.log("Adding contentHash column to existing database...", category: .database)
                do {
                    try db?.run(itemsTable.addColumn(contentHashCol, defaultValue: ""))
                    Logger.log("contentHash column added successfully", category: .database)

                    // 为现有数据生成 contentHash
                    if let items = try db?.prepare(itemsTable) {
                        var count = 0
                        for item in items {
                            do {
                                let id = try item.get(idCol)
                                let content = try item.get(contentCol)
                                let hash = hashContent(content)
                                try db?.run(itemsTable.filter(idCol == id).update(contentHashCol <- hash))
                                count += 1
                            } catch {
                                Logger.error("Error updating item: \(error)", category: .database)
                            }
                        }
                        Logger.log("Generated contentHash for \(count) existing items", category: .database)
                    }
                } catch {
                    Logger.error("Error adding contentHash column: \(error)", category: .database)
                }
            }

            // 创建索引以优化查询
            try db?.run(itemsTable.createIndex(contentHashCol, unique: false, ifNotExists: true))
            try db?.run(itemsTable.createIndex(createdAtCol, ifNotExists: true))

            // 仅在生产模式下执行自动清理
            if !isTestMode {
                cleanExpiredItems()
                limitHistoryCount()
            }

        } catch {
            Logger.error("Database setup error: \(error)", category: .database)
        }
    }

    // MARK: - CRUD Operations

    @discardableResult
    func save(_ item: ClipboardItem) -> Bool {
        let result = queue.sync { () -> Bool in
            do {
                // 对于图片类型，使用图片数据的哈希；对于其他类型，使用文本内容的哈希
                let hash: String
                if item.contentType == .image, let imageData = item.imageData {
                    hash = hashData(imageData)
                } else {
                    hash = hashContent(item.content)
                }

                // 检查是否已存在相同内容
                let existingItem = itemsTable.filter(contentHashCol == hash)

                if let existing = try db?.pluck(existingItem) {
                    let existingId = try existing.get(idCol)

                    // 更新时间戳和其他字段
                    var updateBuilders: [SQLite.Setter] = []
                    updateBuilders.append(createdAtCol <- item.createdAt.timeIntervalSince1970)

                    // 可选字段单独处理
                    if let sourceApp = item.sourceApp {
                        updateBuilders.append(sourceAppCol <- sourceApp)
                    }
                    if let bundle = item.sourceAppBundle {
                        updateBuilders.append(sourceAppBundleCol <- bundle)
                    }
                    if let expiresAt = item.expiresAt {
                        updateBuilders.append(expiresAtCol <- expiresAt.timeIntervalSince1970)
                    }
                    if let imageData = item.imageData {
                        updateBuilders.append(imageDataCol <- imageData)
                    }
                    if let ocrText = item.ocrText {
                        updateBuilders.append(ocrTextCol <- ocrText)
                    }

                    let updateItem = itemsTable.filter(idCol == existingId)
                    try db?.run(updateItem.update(updateBuilders))
                    return false
                }

                // 不存在，插入新记录
                let insert = itemsTable.insert(
                    idCol <- item.id.uuidString,
                    contentCol <- item.content,
                    contentHashCol <- hash,
                    contentTypeCol <- item.contentType.rawValue,
                    sourceAppCol <- item.sourceApp,
                    sourceAppBundleCol <- item.sourceAppBundle,
                    createdAtCol <- item.createdAt.timeIntervalSince1970,
                    isPinnedCol <- item.isPinned,
                    expiresAtCol <- item.expiresAt?.timeIntervalSince1970,
                    imageDataCol <- item.imageData,
                    ocrTextCol <- item.ocrText
                )
                try db?.run(insert)

                return true

            } catch {
                Logger.error("Save error: \(error)", category: .database)
                return false
            }
        }

        // 在 queue.sync 外部异步清理（避免死锁）
        if result {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.limitHistoryCount()
            }
        }

        return result
    }

    // 刷新项目的时间戳（用于选中时移到顶部）
    func refreshTimestamp(_ itemId: UUID) {
        queue.sync { [weak self] in
            guard let self = self else { return }
            do {
                let itemToUpdate = self.itemsTable.filter(self.idCol == itemId.uuidString)
                try self.db?.run(itemToUpdate.update(self.createdAtCol <- Date().timeIntervalSince1970))
            } catch {
                Logger.error("Refresh timestamp error: \(error)", category: .database)
            }
        }
    }

    private func hashContent(_ content: String) -> String {
        return content.sha256()
    }

    private func hashData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func loadAll() -> [ClipboardItem] {
        return queue.sync {
            var items: [ClipboardItem] = []
            guard let database = db else { return items }
            do {
                let query = itemsTable.order(isPinnedCol.desc, createdAtCol.desc)
                for row in try database.prepare(query) {
                    if let item = parseRow(row) {
                        items.append(item)
                    }
                }
            } catch {
                Logger.error("Load error: \(error)", category: .database)
            }
            return items
        }
    }

    func delete(_ itemId: UUID) {
        queue.sync {
            do {
                let itemToDelete = itemsTable.filter(idCol == itemId.uuidString)
                try db?.run(itemToDelete.delete())
            } catch {
                Logger.error("Delete error: \(error)", category: .database)
            }
        }
    }

    func togglePin(_ itemId: UUID) {
        queue.sync {
            do {
                let itemToUpdate = itemsTable.filter(idCol == itemId.uuidString)
                if let row = try db?.pluck(itemToUpdate) {
                    let currentPinned = try row.get(isPinnedCol)
                    try db?.run(itemToUpdate.update(isPinnedCol <- !currentPinned))
                    if !currentPinned {
                        try db?.run(itemToUpdate.update(expiresAtCol <- nil))
                    }
                }
            } catch {
                Logger.error("Toggle pin error: \(error)", category: .database)
            }
        }
    }

    func updateOCRText(_ itemId: UUID, text: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let itemToUpdate = self.itemsTable.filter(self.idCol == itemId.uuidString)
                try self.db?.run(itemToUpdate.update(self.ocrTextCol <- text))
            } catch {
                Logger.error("Update OCR error: \(error)", category: .database)
            }
        }
    }

    /// 同步更新 OCR 文本（确保在 loadAll 之前完成）
    func updateOCRTextSync(_ itemId: UUID, text: String) {
        queue.sync {
            do {
                let itemToUpdate = itemsTable.filter(idCol == itemId.uuidString)
                try db?.run(itemToUpdate.update(ocrTextCol <- text))
            } catch {
                Logger.error("Update OCR sync error: \(error)", category: .database)
            }
        }
    }

    // MARK: - Cleanup

    /// 清理过期项目（测试时可调用）
    func cleanExpiredItems() {
        queue.sync {
            do {
                let now = Date().timeIntervalSince1970
                let expiredItems = itemsTable
                    .filter(expiresAtCol != nil && expiresAtCol < now && isPinnedCol == false)
                try db?.run(expiredItems.delete())
            } catch {
                Logger.error("Clean expired error: \(error)", category: .database)
            }
        }
    }

    /// 限制历史记录数量（测试时可调用）
    /// - Parameter customLimit: 自定义限制数量，传 nil 则使用 UserDefaults 中的值
    func limitHistoryCount(customLimit: Int? = nil) {
        queue.sync {
            let maxCount = customLimit ?? UserDefaults.standard.integer(forKey: "maxHistoryCount")
            let limit = maxCount > 0 ? maxCount : 500
            guard let database = db else { return }

            do {
                // 统计未置顶的项目数量
                let count = try database.scalar(itemsTable.filter(isPinnedCol == false).count)

                if count > limit {
                    // 找出需要删除的最旧的项目（只删除未置顶的）
                    let deleteCount = count - limit
                    let itemsToDelete = itemsTable
                        .filter(isPinnedCol == false)
                        .order(createdAtCol.asc)
                        .limit(deleteCount)

                    // 批量删除
                    let idsToDelete = try database.prepare(itemsToDelete).compactMap { try? $0.get(idCol) }
                    for id in idsToDelete {
                        try database.run(itemsTable.filter(idCol == id).delete())
                    }

                    Logger.log("清理了 \(deleteCount) 条历史记录（当前限制: \(limit)）", category: .database)
                }
            } catch {
                Logger.error("Limit history error: \(error)", category: .database)
            }
        }
    }

    // MARK: - Search

    func search(query: String, sourceApp: String? = nil) -> [ClipboardItem] {
        return queue.sync { () -> [ClipboardItem] in
            var items: [ClipboardItem] = []
            guard let database = db else { return items }
            do {
                var searchQuery = itemsTable

                if !query.isEmpty {
                    // 使用 LOWER() 函数实现大小写不敏感和中文支持
                    let lowerQuery = query.lowercased()
                    let lowerContent = contentCol.lowercaseString
                    let lowerOcrText = ocrTextCol.lowercaseString

                    searchQuery = searchQuery.filter(
                        lowerContent.like("%\(lowerQuery)%") ||
                        (ocrTextCol != nil && lowerOcrText.like("%\(lowerQuery)%"))
                    )
                }

                if let app = sourceApp {
                    searchQuery = searchQuery.filter(sourceAppCol == app)
                }

                searchQuery = searchQuery.order(isPinnedCol.desc, createdAtCol.desc)

                for row in try database.prepare(searchQuery) {
                    if let item = parseRow(row) {
                        items.append(item)
                    }
                }
            } catch {
                Logger.error("Search error: \(error)", category: .database)
            }
            return items
        }
    }

    func getUniqueSourceApps() -> [String] {
        return queue.sync {
            var apps: [String] = []
            guard let database = db else { return apps }
            do {
                let query = itemsTable
                    .select(distinct: sourceAppCol)
                    .filter(sourceAppCol != nil)
                    .order(sourceAppCol)

                for row in try database.prepare(query) {
                    if let app = try row.get(sourceAppCol) {
                        apps.append(app)
                    }
                }
            } catch {
                Logger.error("Get source apps error: \(error)", category: .database)
            }
            return apps
        }
    }

    // MARK: - Helpers

    private func parseRow(_ row: Row) -> ClipboardItem? {
        do {
            let idString = try row.get(idCol)
            let content = try row.get(contentCol)
            let contentTypeRaw = try row.get(contentTypeCol)
            let sourceApp = try row.get(sourceAppCol)
            let sourceAppBundle = try row.get(sourceAppBundleCol)
            let createdAtInterval = try row.get(createdAtCol)
            let isPinned = try row.get(isPinnedCol)
            let expiresAtInterval = try row.get(expiresAtCol)
            let imageData = try row.get(imageDataCol)
            let ocrText = try row.get(ocrTextCol)

            guard let id = UUID(uuidString: idString),
                  let contentType = ContentType(rawValue: contentTypeRaw) else {
                return nil
            }

            return ClipboardItem(
                id: id,
                content: content,
                contentType: contentType,
                sourceApp: sourceApp,
                sourceAppBundle: sourceAppBundle,
                createdAt: Date(timeIntervalSince1970: createdAtInterval),
                isPinned: isPinned,
                expiresAt: expiresAtInterval.map { Date(timeIntervalSince1970: $0) },
                imageData: imageData,
                ocrText: ocrText
            )
        } catch {
            Logger.error("Parse row error: \(error)", category: .database)
            return nil
        }
    }
}

// MARK: - String SHA256 Extension
extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
