// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

#if canImport(Darwin)
  import SQLite3
#else
  import CSQLite
#endif

// MARK: - NCIUserDBKit.UserDatabase

extension NCIUserDBKit {
  /// 自然輸入法使用者資料庫讀取器
  ///
  /// 自然輸入法的使用者資料庫 (`profile.db`) 為未加密的 SQLite 資料庫，
  /// 包含 `profile` 資料表：
  /// ```sql
  /// CREATE TABLE profile (
  ///   keystrokes TEXT,
  ///   pattern TEXT,
  ///   hits INTEGER,
  ///   isCustom INTEGER,
  ///   timestamp INTEGER
  /// )
  /// ```
  ///
  /// 本工具僅提取 `isCustom == 1` 的條目（使用者手動加詞），
  /// 並以 `timestamp` 排序。
  public final class UserDatabase: Sendable {
    // MARK: Lifecycle

    // MARK: - Initializers

    /// 開啟資料庫
    /// - Parameter path: 資料庫檔案路徑
    public init(path: String) throws {
      self.path = path
      self.actor = .init(label: "NCIUserDBQueue.\(UUID().uuidString)")

      // sbooth/CSQLite is built with SQLITE_OMIT_AUTOINIT, so we need to call sqlite3_initialize() first.
      #if !canImport(Darwin)
        sqlite3_initialize()
      #endif

      var dbPointer: OpaquePointer?
      guard sqlite3_open_v2(path, &dbPointer, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
        let errorMessage: String
        if let dbPointer {
          errorMessage = String(cString: sqlite3_errmsg(dbPointer))
          sqlite3_close(dbPointer)
        } else {
          errorMessage = "Unknown error"
        }
        throw DatabaseError.openFailed(message: errorMessage)
      }
      self.db = dbPointer
    }

    deinit {
      actor.sync {
        if let db {
          sqlite3_close(db)
        }
      }
    }

    // MARK: Public

    // MARK: - Database Discovery

    /// 在 macOS 上尋找所有自然輸入法使用者資料庫
    /// - Returns: 找到的資料庫檔案路徑陣列
    public static func findDatabases() -> [URL] {
      var results: [URL] = []

      // Always attempt both common locations; the loops are harmless on other
      // platforms and make the behaviour dependable even if runtime platform
      // detection is unreliable.

      // macOS-style path – look under ~/Library/Application Support
      #if canImport(Darwin)
        let homeURL = URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir))
        let appSupport = homeURL.appendingPathComponent("Library/Application Support")
        for version in NCIUserDBKit.versionRange {
          let dbURL = appSupport
            .appendingPathComponent("GOING\(version)/UserData/Going\(version)/profile.db")
          if FileManager.default.fileExists(atPath: dbURL.path) {
            results.append(dbURL)
          }
        }
      #endif

      // Windows-style path – use APPDATA environment variable if present
      if let appData = ProcessInfo.processInfo.environment["APPDATA"], !appData.isEmpty {
        for version in NCIUserDBKit.versionRange {
          let dbURL = URL(fileURLWithPath: appData)
            .appendingPathComponent("Going\(version)")
            .appendingPathComponent("profile.db")
          if FileManager.default.fileExists(atPath: dbURL.path) {
            results.append(dbURL)
          }
        }
      }

      return results
    }

    // MARK: - Public Methods

    /// 讀取所有使用者自訂詞條（isCustom == 1），以 timestamp 排序
    public func fetchGrams() throws -> [NCIGram] {
      try actor.sync {
        let sql = """
        SELECT keystrokes, pattern, hits, timestamp
        FROM profile
        WHERE isCustom = 1
        ORDER BY timestamp
        """
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
          throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }

        defer { sqlite3_finalize(statement) }

        var results: [NCIGram] = []

        while sqlite3_step(statement) == SQLITE_ROW {
          let keystrokes = String(cString: sqlite3_column_text(statement, 0))
          let pattern = String(cString: sqlite3_column_text(statement, 1))
          let hits = Int(sqlite3_column_int(statement, 2))
          let timestamp = Int64(sqlite3_column_int64(statement, 3))

          results.append(NCIGram(
            keystrokes: keystrokes,
            pattern: pattern,
            hits: hits,
            timestamp: timestamp
          ))
        }

        return results
      }
    }

    /// 建立一個迭代器，逐行讀取所有使用者自訂詞條
    /// - Returns: `GramIterator` 迭代器
    public func makeIterator() -> GramIterator {
      GramIterator(database: self)
    }

    // MARK: Fileprivate

    fileprivate func prepareStatement(sql: String) throws -> OpaquePointer {
      try actor.sync {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
          throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
        }
        return statement!
      }
    }

    fileprivate func stepStatement(_ statement: OpaquePointer) -> Int32 {
      actor.sync {
        sqlite3_step(statement)
      }
    }

    fileprivate func finalizeStatement(_ statement: OpaquePointer) {
      _ = actor.sync {
        sqlite3_finalize(statement)
      }
    }

    // MARK: Private

    private nonisolated(unsafe) let db: OpaquePointer?
    private let path: String
    private let actor: DispatchQueue
  }
}

// MARK: - NCIUserDBKit.UserDatabase + Sequence

extension NCIUserDBKit.UserDatabase: Sequence {
  public typealias Element = NCIUserDBKit.NCIGram
  public typealias Iterator = GramIterator

  /// 用於逐行迭代資料庫中所有 Gram 的迭代器
  public final class GramIterator: IteratorProtocol, Sendable {
    // MARK: Lifecycle

    fileprivate init(database: NCIUserDBKit.UserDatabase) {
      self.database = database
      self.iteratorQueue = DispatchQueue(label: "GramIterator.\(UUID().uuidString)")
      self._currentStatement = nil
      self._prepared = false
    }

    deinit {
      cleanup()
    }

    // MARK: Public

    public typealias Element = NCIUserDBKit.NCIGram

    public func next() -> NCIUserDBKit.NCIGram? {
      iteratorQueue.sync {
        if !_prepared {
          do {
            let sql = """
            SELECT keystrokes, pattern, hits, timestamp
            FROM profile
            WHERE isCustom = 1
            ORDER BY timestamp
            """
            _currentStatement = try database.prepareStatement(sql: sql)
            _prepared = true
          } catch {
            return nil
          }
        }

        guard let statement = _currentStatement else { return nil }

        let result = database.stepStatement(statement)
        if result == SQLITE_ROW {
          let keystrokes = String(cString: sqlite3_column_text(statement, 0))
          let pattern = String(cString: sqlite3_column_text(statement, 1))
          let hits = Int(sqlite3_column_int(statement, 2))
          let timestamp = Int64(sqlite3_column_int64(statement, 3))

          return NCIUserDBKit.NCIGram(
            keystrokes: keystrokes,
            pattern: pattern,
            hits: hits,
            timestamp: timestamp
          )
        } else {
          cleanupUnsafe()
          return nil
        }
      }
    }

    // MARK: Private

    private let database: NCIUserDBKit.UserDatabase
    private let iteratorQueue: DispatchQueue
    private nonisolated(unsafe) var _currentStatement: OpaquePointer?
    private nonisolated(unsafe) var _prepared: Bool

    private func cleanup() {
      iteratorQueue.sync {
        cleanupUnsafe()
      }
    }

    private func cleanupUnsafe() {
      if let statement = _currentStatement {
        database.finalizeStatement(statement)
        _currentStatement = nil
      }
    }
  }
}

// MARK: - AsyncGramSequence

#if canImport(Darwin)
  @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
#endif
extension NCIUserDBKit.UserDatabase {
  /// 取得非同步序列，用於在 async 環境中迭代資料庫
  public var async: AsyncGramSequence {
    AsyncGramSequence(database: self)
  }

  /// 用於非同步迭代資料庫中所有 Gram 的序列
  public struct AsyncGramSequence: AsyncSequence {
    // MARK: Public

    public typealias Element = NCIUserDBKit.NCIGram

    public func makeAsyncIterator() -> AsyncGramIterator {
      AsyncGramIterator(database: database)
    }

    // MARK: Fileprivate

    fileprivate let database: NCIUserDBKit.UserDatabase
  }

  /// 用於非同步逐行迭代資料庫中所有 Gram 的迭代器
  public final class AsyncGramIterator: AsyncIteratorProtocol, Sendable {
    // MARK: Lifecycle

    fileprivate init(database: NCIUserDBKit.UserDatabase) {
      self.database = database
      self.iteratorQueue = DispatchQueue(label: "AsyncGramIterator.\(UUID().uuidString)")
      self._currentStatement = nil
      self._prepared = false
    }

    deinit {
      cleanup()
    }

    // MARK: Public

    public typealias Element = NCIUserDBKit.NCIGram

    public func next() async -> NCIUserDBKit.NCIGram? {
      iteratorQueue.sync {
        if !_prepared {
          do {
            let sql = """
            SELECT keystrokes, pattern, hits, timestamp
            FROM profile
            WHERE isCustom = 1
            ORDER BY timestamp
            """
            _currentStatement = try database.prepareStatement(sql: sql)
            _prepared = true
          } catch {
            return nil
          }
        }

        guard let statement = _currentStatement else { return nil }

        let result = database.stepStatement(statement)
        if result == SQLITE_ROW {
          let keystrokes = String(cString: sqlite3_column_text(statement, 0))
          let pattern = String(cString: sqlite3_column_text(statement, 1))
          let hits = Int(sqlite3_column_int(statement, 2))
          let timestamp = Int64(sqlite3_column_int64(statement, 3))

          return NCIUserDBKit.NCIGram(
            keystrokes: keystrokes,
            pattern: pattern,
            hits: hits,
            timestamp: timestamp
          )
        } else {
          cleanupUnsafe()
          return nil
        }
      }
    }

    // MARK: Private

    private let database: NCIUserDBKit.UserDatabase
    private let iteratorQueue: DispatchQueue
    private nonisolated(unsafe) var _currentStatement: OpaquePointer?
    private nonisolated(unsafe) var _prepared: Bool

    private func cleanup() {
      iteratorQueue.sync {
        cleanupUnsafe()
      }
    }

    private func cleanupUnsafe() {
      if let statement = _currentStatement {
        database.finalizeStatement(statement)
        _currentStatement = nil
      }
    }
  }
}

// MARK: - NCIUserDBKit.DatabaseError

extension NCIUserDBKit {
  /// 資料庫錯誤類型
  public enum DatabaseError: Error, LocalizedError {
    /// 開啟資料庫失敗
    case openFailed(message: String)
    /// 查詢失敗
    case queryFailed(message: String)

    // MARK: Public

    /// 錯誤描述
    public var errorDescription: String? {
      switch self {
      case let .openFailed(message):
        return "Failed to open database: \(message)"
      case let .queryFailed(message):
        return "Query failed: \(message)"
      }
    }
  }
}
