// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

/// NCIUserDBKit - 自然輸入法（Natural Chinese Input）使用者資料庫工具
///
/// 此套件提供讀取自然輸入法 (NCI, codename GOING) 使用者資料庫的功能。
///
/// ## 主要元件
///
/// - ``NCIUserDBKit/UserDatabase``: 使用者資料庫讀取器
/// - ``NCIUserDBKit/Gram``: 通用語料結構體
///
/// ## 使用範例
///
/// ```swift
/// import NCIUserDBKit
///
/// // 讀取所有自然輸入法使用者資料庫
/// let databases = NCIUserDBKit.UserDatabase.findDatabases()
///
/// for dbURL in databases {
///     let db = try NCIUserDBKit.UserDatabase(path: dbURL.path)
///     let grams = try db.fetchGrams()
///     for gram in grams {
///         print("\(gram.current) → \(gram.keyArray.joined(separator: "-"))")
///     }
/// }
/// ```
public enum NCIUserDBKit {
  /// 版本號
  public static let version = "1.0.3"

  /// 自然輸入法 codename
  public static let codename = "GOING"

  /// 支援的版本號範圍
  public static let versionRange: ClosedRange<Int> = 10 ... 99
}
