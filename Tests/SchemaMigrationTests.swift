//
//  SchemaMigrationTests.swift
//  WXLTests
//
//  Regression tests for schema migrations on legacy databases
//

import XCTest
import SQLite3
@testable import WXL

final class SchemaMigrationTests: XCTestCase {

    private var dbPath: String!

    override func setUp() {
        super.setUp()
        dbPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration_\(UUID().uuidString).db").path
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: dbPath)
        super.tearDown()
    }

    /// 用 1.4.0 的 schema 建表并写入一条存量数据（模拟老版本用户的库）
    private func createLegacyDatabase() {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let sql = """
        CREATE TABLE IF NOT EXISTS clipboard_items (
            id TEXT PRIMARY KEY NOT NULL,
            content TEXT NOT NULL,
            contentHash TEXT NOT NULL,
            contentType TEXT NOT NULL,
            sourceApp TEXT,
            sourceAppBundle TEXT,
            createdAt REAL NOT NULL,
            isPinned INTEGER NOT NULL DEFAULT 0,
            expiresAt REAL,
            imageData BLOB,
            ocrText TEXT,
            fileURLs TEXT
        );
        """
        XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK)

        let insert = """
        INSERT INTO clipboard_items
            (id, content, contentHash, contentType, createdAt, isPinned)
        VALUES
            ('11111111-1111-1111-1111-111111111111', 'legacy row', 'hash-legacy', 'text', 700000000.0, 0);
        """
        XCTAssertEqual(sqlite3_exec(db, insert, nil, nil, nil), SQLITE_OK)
    }

    private func columnExists(_ name: String) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return false }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(clipboard_items)", -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if String(cString: sqlite3_column_text(stmt, 1)) == name {
                return true
            }
        }
        return false
    }

    private func userVersion() -> Int32 {
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return -1 }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0)
        }
        return -1
    }

    /// 正常升级路径：1.4.0 schema + user_version=0 → 一次迁移到位
    func testMigration_LegacySchemaUpgrade() {
        createLegacyDatabase()

        let storage = ClipboardStorage(databasePath: dbPath)

        XCTAssertTrue(columnExists("thumbnail"), "升级后应补齐 thumbnail 列")
        XCTAssertTrue(storage.save(ClipboardItem(content: "new row")), "升级后新条目应能入库")
        XCTAssertEqual(storage.loadAllLight().count, 2, "存量数据与新数据都应可读")
        XCTAssertEqual(userVersion(), 3, "迁移完成应推进版本号")
    }

    /// 事故现场回归：列缺失但版本号已被标记为 3 → 初始化必须自愈
    /// （v1.5.0 曾在此状态下永久丢弃所有新条目）
    func testMigration_HealsMissingColumnEvenWhenVersionAlreadyMarked() {
        createLegacyDatabase()
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "PRAGMA user_version = 3", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)

        XCTAssertFalse(columnExists("thumbnail"), "前置条件：事故状态下列缺失")

        let storage = ClipboardStorage(databasePath: dbPath)

        XCTAssertTrue(columnExists("thumbnail"), "初始化必须补齐缺失的 thumbnail 列")
        XCTAssertTrue(storage.save(ClipboardItem(content: "healed row")), "自愈后新条目必须能入库")
        XCTAssertEqual(storage.loadAllLight().count, 2)
        XCTAssertEqual(userVersion(), 3)
    }
}
