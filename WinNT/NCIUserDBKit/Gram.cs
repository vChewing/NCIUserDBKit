// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

using System.Text.Json.Serialization;

namespace NCIUserDBKit;

/// <summary>
/// 自然輸入法使用者詞庫條目
/// </summary>
public sealed record Gram : IEquatable<Gram> {
  /// <summary>
  /// 元圖識別碼（讀音陣列）。
  /// </summary>
  [JsonPropertyName("keys")]
  public required string[] KeyArray { get; init; }

  /// <summary>
  /// 當前漢字（詞語）
  /// </summary>
  [JsonPropertyName("curr")]
  public required string Current { get; init; }

  /// <summary>
  /// 使用次數
  /// </summary>
  [JsonPropertyName("hits")]
  public int Hits { get; init; }

  /// <summary>
  /// 時間戳
  /// </summary>
  [JsonPropertyName("ts")]
  public long Timestamp { get; init; }

  /// <summary>
  /// 檢查是否「讀音字長與候選字字長不一致」。
  /// </summary>
  [JsonIgnore]
  public bool IsReadingMismatched => KeyArray.Length != Current.Length;

  /// <summary>
  /// 幅長。
  /// </summary>
  [JsonIgnore]
  public int SegLength => KeyArray.Length;

  /// <summary>
  /// 描述 Gram 的完整資訊
  /// </summary>
  /// <param name="keySeparator">鍵陣列分隔符號</param>
  /// <returns>格式化的描述字串</returns>
  public string Describe(string keySeparator = "-") {
    return $"'{string.Join(keySeparator, KeyArray)}', {Current} (hits={Hits}, ts={Timestamp})";
  }

  /// <inheritdoc/>
  public override string ToString() => Describe();

  /// <inheritdoc/>
  public override int GetHashCode() =>
      HashCode.Combine(
          KeyArray.Aggregate(0, HashCode.Combine),
          Current
      );

  /// <inheritdoc/>
  public bool Equals(Gram? other) {
    if (other is null) return false;
    if (ReferenceEquals(this, other)) return true;
    return KeyArray.SequenceEqual(other.KeyArray)
        && Current == other.Current;
  }

  // Factory methods

  /// <summary>
  /// 建立 Gram（從 keyArray）
  /// </summary>
  public static Gram Create(IEnumerable<string> keyArray, string current, int hits = 0, long timestamp = 0) =>
      new() {
        KeyArray = keyArray.ToArray(),
        Current = current,
        Hits = hits,
        Timestamp = timestamp
      };

  /// <summary>
  /// 建立 Gram（從 keystrokes 字串，以 - 分隔）
  /// </summary>
  public static Gram CreateFromKeystrokes(string keystrokes, string pattern, int hits = 0, long timestamp = 0) =>
      new() {
        KeyArray = keystrokes.Split('-', StringSplitOptions.RemoveEmptyEntries),
        Current = pattern,
        Hits = hits,
        Timestamp = timestamp
      };
}
