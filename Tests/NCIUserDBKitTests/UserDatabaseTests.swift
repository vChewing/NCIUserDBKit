// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import NCIUserDBKit

// MARK: - UserDatabaseTests

@Suite("UserDatabase Tests", .serialized)
struct UserDatabaseTests {
  // MARK: Internal

  // MARK: - Tests

  @Test("Database should open successfully")
  func databaseOpen() throws {
    let dbURL = try createTestDatabase()
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let db = try NCIUserDBKit.UserDatabase(path: dbURL.path)
    _ = db
  }

  @Test("fetchGrams should return only isCustom == 1 sorted by timestamp")
  func fetchGrams_ShouldReturnCustomOnly() throws {
    let dbURL = try createTestDatabase()
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let db = try NCIUserDBKit.UserDatabase(path: dbURL.path)
    let grams = try db.fetchGrams()

    // 應只有 3 筆 (isCustom == 1)
    #expect(grams.count == 3)

    // 應按 timestamp 排序
    #expect(grams[0].current == "大家好") // ts=500
    #expect(grams[1].current == "你好") // ts=1000
    #expect(grams[2].current == "星穹列車") // ts=2000

    // 驗證 keystrokes 正確解析
    #expect(grams[0].keyArray == ["ㄉㄚˋ", "ㄐㄧㄚ", "ㄏㄠˇ"])
    #expect(grams[1].keyArray == ["ㄋㄧˇ", "ㄏㄠˇ"])
    #expect(grams[2].keyArray == ["ㄒㄧㄥ", "ㄑㄩㄥˊ", "ㄌㄧㄝˋ", "ㄔㄜ"])

    // 驗證 hits
    #expect(grams[0].hits == 20)
    #expect(grams[1].hits == 10)
    #expect(grams[2].hits == 5)
  }

  @Test("Sequence iteration should return same count as fetchGrams")
  func sequenceIteration() throws {
    let dbURL = try createTestDatabase()
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let db = try NCIUserDBKit.UserDatabase(path: dbURL.path)

    var iteratedGrams: [NCIUserDBKit.NCIGram] = []
    for gram in db {
      iteratedGrams.append(gram)
    }

    let fetchedGrams = try db.fetchGrams()
    #expect(iteratedGrams.count == fetchedGrams.count)
  }

  @Test("Sequence iterator multiple times should return consistent results")
  func sequenceIteratorMultipleTimes() throws {
    let dbURL = try createTestDatabase()
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let db = try NCIUserDBKit.UserDatabase(path: dbURL.path)

    let firstCount = db.reduce(0) { acc, _ in acc + 1 }
    let secondCount = db.reduce(0) { acc, _ in acc + 1 }

    #expect(firstCount == secondCount)
    #expect(firstCount == 3)
  }

  @Test("Database open with invalid path should throw openFailed error")
  func databaseOpenFailure() {
    #expect(throws: NCIUserDBKit.DatabaseError.self) {
      try NCIUserDBKit.UserDatabase(path: "/nonexistent/path/to/database.db")
    }
  }

  // MARK: - AsyncSequence Tests

  @Test("AsyncSequence iteration should return same count as fetchGrams")
  func asyncSequenceIteration() async throws {
    let dbURL = try createTestDatabase()
    defer { try? FileManager.default.removeItem(at: dbURL) }

    let db = try NCIUserDBKit.UserDatabase(path: dbURL.path)

    var iteratedGrams: [NCIUserDBKit.NCIGram] = []
    for await gram in db.async {
      iteratedGrams.append(gram)
    }

    let fetchedGrams = try db.fetchGrams()
    #expect(iteratedGrams.count == fetchedGrams.count)
  }

  @Test("findDatabases should return array")
  func findDatabases_ShouldReturnArray() {
    let databases = NCIUserDBKit.UserDatabase.findDatabases()
    // 不一定有安裝自然輸入法，但呼叫不應拋出錯誤
    _ = databases
  }

  // MARK: Private

  // MARK: - Helper: Create Test Database

  /// 建立一個含有測試資料的 SQLite 資料庫
  private func createTestDatabase() throws -> URL {
    // sbooth/CSQLite is built with SQLITE_OMIT_AUTOINIT, so we must
    // call sqlite3_initialize() before any SQLite API usage on Linux.
    #if !canImport(Darwin)
      sqlite3_initialize()
    #endif

    let tempDir = FileManager.default.temporaryDirectory
    let dbURL = tempDir.appendingPathComponent("nci_test_\(UUID().uuidString).db")

    var db: OpaquePointer?
    guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
      throw NCIUserDBKit.DatabaseError.openFailed(message: "Cannot create test database")
    }
    defer { sqlite3_close(db) }

    // 建立 profile 表
    let createSQL = """
    CREATE TABLE profile (
      keystrokes TEXT,
      pattern TEXT,
      hits INTEGER,
      isCustom INTEGER,
      timestamp INTEGER
    )
    """
    guard sqlite3_exec(db, createSQL, nil, nil, nil) == SQLITE_OK else {
      throw NCIUserDBKit.DatabaseError.queryFailed(
        message: String(cString: sqlite3_errmsg(db))
      )
    }

    // 插入測試資料
    let insertSQL =
      "INSERT INTO profile (keystrokes, pattern, hits, isCustom, timestamp) VALUES (?, ?, ?, ?, ?)"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
      throw NCIUserDBKit.DatabaseError.queryFailed(
        message: String(cString: sqlite3_errmsg(db))
      )
    }
    defer { sqlite3_finalize(stmt) }

    let testData: [(String, String, Int32, Int32, Int64)] = [
      ("ㄋㄧˇ-ㄏㄠˇ", "你好", 10, 1, 1_000),
      ("ㄒㄧㄥ-ㄑㄩㄥˊ-ㄌㄧㄝˋ-ㄔㄜ", "星穹列車", 5, 1, 2_000),
      ("ㄉㄚˋ-ㄐㄧㄚ-ㄏㄠˇ", "大家好", 20, 1, 500),
      ("ㄘㄜˋ-ㄕˋ", "測試", 100, 0, 3_000), // isCustom == 0，不應被提取
    ]

    for (keystrokes, pattern, hits, isCustom, timestamp) in testData {
      sqlite3_reset(stmt)
      sqlite3_bind_text(
        stmt,
        1,
        keystrokes,
        -1,
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
      )
      sqlite3_bind_text(stmt, 2, pattern, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
      sqlite3_bind_int(stmt, 3, hits)
      sqlite3_bind_int(stmt, 4, isCustom)
      sqlite3_bind_int64(stmt, 5, timestamp)
      guard sqlite3_step(stmt) == SQLITE_DONE else {
        throw NCIUserDBKit.DatabaseError.queryFailed(
          message: String(cString: sqlite3_errmsg(db))
        )
      }
    }

    return dbURL
  }
}

// MARK: - SQLite3 Import Helper

#if canImport(Darwin)
  import SQLite3
#else
  import CSQLite
#endif
