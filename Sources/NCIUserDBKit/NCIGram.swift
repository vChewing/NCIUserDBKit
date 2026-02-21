// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - NCIUserDBKit.Gram

extension NCIUserDBKit {
  /// 自然輸入法使用者詞庫條目
  public struct NCIGram: Codable, CustomStringConvertible, Equatable, Sendable, Hashable {
    // MARK: Lifecycle

    /// 使用完整參數初始化 Gram
    /// - Parameters:
    ///   - keyArray: 讀音陣列（注音符號）
    ///   - current: 當前漢字（詞語）
    ///   - hits: 使用次數
    ///   - timestamp: 時間戳
    public init(
      keyArray: [String],
      current: String,
      hits: Int = 0,
      timestamp: Int64 = 0
    ) {
      self.keyArray = keyArray
      self.current = current
      self.hits = hits
      self.timestamp = timestamp
    }

    /// 從 keystrokes 字串初始化（以 `-` 分隔的注音讀音串）
    /// - Parameters:
    ///   - keystrokes: 注音讀音串（例：`ㄒㄧㄥ-ㄑㄩㄥˊ-ㄌㄧㄝˋ-ㄔㄜ`）
    ///   - pattern: 詞語
    ///   - hits: 使用次數
    ///   - timestamp: 時間戳
    public init(
      keystrokes: String,
      pattern: String,
      hits: Int = 0,
      timestamp: Int64 = 0
    ) {
      self.keyArray = keystrokes.split(separator: "-").map(String.init)
      self.current = pattern
      self.hits = hits
      self.timestamp = timestamp
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.keyArray = try container.decode([String].self, forKey: .keyArray)
      self.current = try container.decode(String.self, forKey: .current)
      self.hits = (try container.decodeIfPresent(Int.self, forKey: .hits)) ?? 0
      self.timestamp = (try container.decodeIfPresent(Int64.self, forKey: .timestamp)) ?? 0
    }

    // MARK: Public

    /// 元圖識別碼（讀音陣列）
    public let keyArray: [String]
    /// 當前漢字（詞語）
    public let current: String
    /// 使用次數
    public let hits: Int
    /// 時間戳
    public let timestamp: Int64

    /// 檢查是否「讀音字長與候選字字長不一致」
    public var isReadingMismatched: Bool {
      keyArray.count != current.count
    }

    /// 幅長（讀音數量）
    public var segLength: Int {
      keyArray.count
    }

    /// 文字描述
    public var description: String {
      describe(keySeparator: "-")
    }

    /// 判斷兩個 Gram 是否相等
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.keyArray == rhs.keyArray && lhs.current == rhs.current
    }

    /// 產生帶有指定分隔符的描述文字
    /// - Parameter keySeparator: 讀音分隔符
    /// - Returns: 格式化的描述文字
    public func describe(keySeparator: String) -> String {
      "'\(keyArray.joined(separator: keySeparator))', \(current) (hits=\(hits), ts=\(timestamp))"
    }

    /// 預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyArray)
      hasher.combine(current)
    }

    /// 編碼至指定編碼器
    /// - Parameter encoder: 編碼器
    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(keyArray, forKey: .keyArray)
      try container.encode(current, forKey: .current)
      try container.encode(hits, forKey: .hits)
      try container.encode(timestamp, forKey: .timestamp)
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
      case keyArray = "keys"
      case current = "curr"
      case hits
      case timestamp = "ts"
    }
  }
}
