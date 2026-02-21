// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

using Xunit;

namespace NCIUserDBKit.Tests;

public class GramTests {
  [Fact]
  public void Create_ShouldSetCorrectProperties() {
    var keyArray = new[] { "ㄋㄧˇ", "ㄏㄠˇ" };
    var current = "你好";

    var gram = Gram.Create(keyArray, current, hits: 5, timestamp: 1000);

    Assert.Equal(keyArray, gram.KeyArray);
    Assert.Equal(current, gram.Current);
    Assert.Equal(5, gram.Hits);
    Assert.Equal(1000, gram.Timestamp);
  }

  [Fact]
  public void CreateFromKeystrokes_ShouldSplitCorrectly() {
    var gram = Gram.CreateFromKeystrokes("ㄒㄧㄥ-ㄑㄩㄥˊ-ㄌㄧㄝˋ-ㄔㄜ", "星穹列車", 3, 2000);

    Assert.Equal(new[] { "ㄒㄧㄥ", "ㄑㄩㄥˊ", "ㄌㄧㄝˋ", "ㄔㄜ" }, gram.KeyArray);
    Assert.Equal("星穹列車", gram.Current);
    Assert.Equal(3, gram.Hits);
    Assert.Equal(2000, gram.Timestamp);
  }

  [Fact]
  public void Create_WithDefaults() {
    var gram = Gram.Create(["ㄏㄠˇ"], "好");

    Assert.Equal(0, gram.Hits);
    Assert.Equal(0, gram.Timestamp);
  }

  [Fact]
  public void IsReadingMismatched_WhenLengthsDiffer_ShouldReturnTrue() {
    var gram = Gram.Create(["ㄋㄧˇ", "ㄏㄠˇ"], "你好嗎"); // 2 keys, 3 chars
    Assert.True(gram.IsReadingMismatched);
  }

  [Fact]
  public void IsReadingMismatched_WhenLengthsMatch_ShouldReturnFalse() {
    var gram = Gram.Create(["ㄋㄧˇ", "ㄏㄠˇ"], "你好"); // 2 keys, 2 chars
    Assert.False(gram.IsReadingMismatched);
  }

  [Fact]
  public void SegLength_ShouldReturnKeyArrayLength() {
    var gram = Gram.Create(["ㄋㄧˇ", "ㄏㄠˇ", "ㄇㄚ"], "你好嗎");
    Assert.Equal(3, gram.SegLength);
  }

  [Fact]
  public void Describe_ShouldIncludeReadingAndCurrent() {
    var gram = Gram.Create(["ㄋㄧˇ", "ㄏㄠˇ"], "你好", 5, 1000);
    var description = gram.Describe();

    Assert.Contains("ㄋㄧˇ-ㄏㄠˇ", description);
    Assert.Contains("你好", description);
    Assert.Contains("hits=5", description);
    Assert.Contains("ts=1000", description);
  }

  [Fact]
  public void ToString_ShouldCallDescribe() {
    var gram = Gram.Create(["ㄋㄧˇ"], "你");
    Assert.Equal(gram.Describe(), gram.ToString());
  }

  [Fact]
  public void Equality_SameValues_ShouldBeEqual() {
    var gram1 = Gram.Create(["ㄋㄧˇ"], "你");
    var gram2 = Gram.Create(["ㄋㄧˇ"], "你");

    Assert.True(gram1.Equals(gram2));
    Assert.Equal(gram1.GetHashCode(), gram2.GetHashCode());
  }

  [Fact]
  public void Equality_DifferentValues_ShouldNotBeEqual() {
    var gram1 = Gram.Create(["ㄋㄧˇ"], "你");
    var gram2 = Gram.Create(["ㄋㄧˇ"], "妳");

    Assert.False(gram1.Equals(gram2));
  }

  [Fact]
  public void Equality_WithNull_ShouldNotBeEqual() {
    var gram = Gram.Create(["ㄋㄧˇ"], "你");
    Assert.False(gram.Equals(null));
  }
}
