// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Testing

@testable import NCIUserDBKit

@Suite("Gram Tests")
struct GramTests {
  // MARK: - Creation Tests

  @Test("Create Gram with keyArray should set correct properties")
  func createGram_WithKeyArray_ShouldSetCorrectProperties() {
    let keyArray = ["ㄋㄧˇ", "ㄏㄠˇ"]
    let current = "你好"

    let gram = NCIUserDBKit.NCIGram(
      keyArray: keyArray,
      current: current,
      hits: 5,
      timestamp: 1_000
    )

    #expect(gram.keyArray == keyArray)
    #expect(gram.current == current)
    #expect(gram.hits == 5)
    #expect(gram.timestamp == 1_000)
  }

  @Test("Create Gram from keystrokes should split correctly")
  func createGram_FromKeystrokes_ShouldSplitCorrectly() {
    let gram = NCIUserDBKit.NCIGram(
      keystrokes: "ㄒㄧㄥ-ㄑㄩㄥˊ-ㄌㄧㄝˋ-ㄔㄜ",
      pattern: "星穹列車",
      hits: 3,
      timestamp: 2_000
    )

    #expect(gram.keyArray == ["ㄒㄧㄥ", "ㄑㄩㄥˊ", "ㄌㄧㄝˋ", "ㄔㄜ"])
    #expect(gram.current == "星穹列車")
    #expect(gram.hits == 3)
    #expect(gram.timestamp == 2_000)
  }

  @Test("Create Gram with defaults")
  func createGram_WithDefaults() {
    let gram = NCIUserDBKit.NCIGram(
      keyArray: ["ㄏㄠˇ"],
      current: "好"
    )

    #expect(gram.hits == 0)
    #expect(gram.timestamp == 0)
  }

  // MARK: - Property Tests

  @Test("isReadingMismatched should return true when lengths differ")
  func isReadingMismatched_WhenLengthsDiffer_ShouldReturnTrue() {
    let gram = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ", "ㄏㄠˇ"],
      current: "你好嗎" // 2 keys, 3 chars
    )
    #expect(gram.isReadingMismatched == true)
  }

  @Test("isReadingMismatched should return false when lengths match")
  func isReadingMismatched_WhenLengthsMatch_ShouldReturnFalse() {
    let gram = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ", "ㄏㄠˇ"],
      current: "你好" // 2 keys, 2 chars
    )
    #expect(gram.isReadingMismatched == false)
  }

  @Test("segLength should return keyArray length")
  func segLength_ShouldReturnKeyArrayLength() {
    let gram = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ", "ㄏㄠˇ", "ㄇㄚ"],
      current: "你好嗎"
    )
    #expect(gram.segLength == 3)
  }

  // MARK: - Description Tests

  @Test("describe should include reading and current text")
  func describe_ShouldIncludeReadingAndCurrent() {
    let gram = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ", "ㄏㄠˇ"],
      current: "你好",
      hits: 5,
      timestamp: 1_000
    )
    let description = gram.describe(keySeparator: "-")

    #expect(description.contains("ㄋㄧˇ-ㄏㄠˇ"))
    #expect(description.contains("你好"))
    #expect(description.contains("hits=5"))
    #expect(description.contains("ts=1000"))
  }

  @Test("description should use dash separator")
  func description_ShouldUseDashSeparator() {
    let gram = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ"],
      current: "你"
    )
    #expect(gram.description == gram.describe(keySeparator: "-"))
  }

  // MARK: - Equality Tests

  @Test("Equality with same values should be equal")
  func equality_SameValues_ShouldBeEqual() {
    let gram1 = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ"],
      current: "你"
    )
    let gram2 = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ"],
      current: "你"
    )

    #expect(gram1 == gram2)
    #expect(gram1.hashValue == gram2.hashValue)
  }

  @Test("Equality with different values should not be equal")
  func equality_DifferentValues_ShouldNotBeEqual() {
    let gram1 = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ"],
      current: "你"
    )
    let gram2 = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ"],
      current: "妳"
    )

    #expect(gram1 != gram2)
  }

  // MARK: - Codable Tests

  @Test("Codable encode/decode should preserve values")
  func codable_EncodeDecode_ShouldPreserveValues() throws {
    let originalGram = NCIUserDBKit.NCIGram(
      keyArray: ["ㄋㄧˇ", "ㄏㄠˇ"],
      current: "你好",
      hits: 10,
      timestamp: 12_345
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(originalGram)

    let decoder = JSONDecoder()
    let decodedGram = try decoder.decode(NCIUserDBKit.NCIGram.self, from: data)

    #expect(originalGram == decodedGram)
    #expect(originalGram.hits == decodedGram.hits)
    #expect(originalGram.timestamp == decodedGram.timestamp)
  }
}
