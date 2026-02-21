// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

using Microsoft.Data.Sqlite;

using Xunit;

namespace NCIUserDBKit.Tests;

public class UserDatabaseTests : IDisposable {
  private readonly string _testDbPath;

  public UserDatabaseTests() {
    _testDbPath = Path.Combine(Path.GetTempPath(), $"nci_test_{Guid.NewGuid()}.db");
    CreateTestDatabase(_testDbPath);
  }

  public void Dispose() {
    for (var i = 0; i < 3; i++) {
      try {
        if (File.Exists(_testDbPath)) {
          File.Delete(_testDbPath);
        }
        break;
      } catch (IOException) {
        if (i < 2) {
          Thread.Sleep(100);
        }
      }
    }
  }

  private static void CreateTestDatabase(string path) {
    var connectionString = new SqliteConnectionStringBuilder {
      DataSource = path,
      Mode = SqliteOpenMode.ReadWriteCreate
    }.ToString();

    using var connection = new SqliteConnection(connectionString);
    connection.Open();

    using var createCmd = new SqliteCommand("""
      CREATE TABLE profile (
        keystrokes TEXT,
        pattern TEXT,
        hits INTEGER,
        isCustom INTEGER,
        timestamp INTEGER
      )
      """, connection);
    createCmd.ExecuteNonQuery();

    var testData = new (string keystrokes, string pattern, int hits, int isCustom, long timestamp)[] {
      ("ㄋㄧˇ-ㄏㄠˇ", "你好", 10, 1, 1000),
      ("ㄒㄧㄥ-ㄑㄩㄥˊ-ㄌㄧㄝˋ-ㄔㄜ", "星穹列車", 5, 1, 2000),
      ("ㄉㄚˋ-ㄐㄧㄚ-ㄏㄠˇ", "大家好", 20, 1, 500),
      ("ㄘㄜˋ-ㄕˋ", "測試", 100, 0, 3000),  // isCustom == 0，不應被提取
    };

    foreach (var (keystrokes, pattern, hits, isCustom, timestamp) in testData) {
      using var insertCmd = new SqliteCommand(
        "INSERT INTO profile (keystrokes, pattern, hits, isCustom, timestamp) VALUES (@k, @p, @h, @c, @t)",
        connection
      );
      insertCmd.Parameters.AddWithValue("@k", keystrokes);
      insertCmd.Parameters.AddWithValue("@p", pattern);
      insertCmd.Parameters.AddWithValue("@h", hits);
      insertCmd.Parameters.AddWithValue("@c", isCustom);
      insertCmd.Parameters.AddWithValue("@t", timestamp);
      insertCmd.ExecuteNonQuery();
    }
  }

  [Fact]
  public void TestDatabaseOpen() {
    using var db = new UserDatabase(_testDbPath);
    Assert.NotNull(db);
  }

  [Fact]
  public void TestFetchGrams_ShouldReturnCustomOnly() {
    using var db = new UserDatabase(_testDbPath);
    var grams = db.FetchGrams();

    // 應只有 3 筆 (isCustom == 1)
    Assert.Equal(3, grams.Count);

    // 應按 timestamp 排序
    Assert.Equal("大家好", grams[0].Current);   // ts=500
    Assert.Equal("你好", grams[1].Current);     // ts=1000
    Assert.Equal("星穹列車", grams[2].Current); // ts=2000

    // 驗證 keystrokes 正確解析
    Assert.Equal(new[] { "ㄉㄚˋ", "ㄐㄧㄚ", "ㄏㄠˇ" }, grams[0].KeyArray);
    Assert.Equal(new[] { "ㄋㄧˇ", "ㄏㄠˇ" }, grams[1].KeyArray);
    Assert.Equal(new[] { "ㄒㄧㄥ", "ㄑㄩㄥˊ", "ㄌㄧㄝˋ", "ㄔㄜ" }, grams[2].KeyArray);

    // 驗證 hits
    Assert.Equal(20, grams[0].Hits);
    Assert.Equal(10, grams[1].Hits);
    Assert.Equal(5, grams[2].Hits);
  }

  [Fact]
  public void TestSequenceIteration() {
    using var db = new UserDatabase(_testDbPath);

    var iteratedGrams = new List<Gram>();
    foreach (var gram in db) {
      iteratedGrams.Add(gram);
    }

    var fetchedGrams = db.FetchGrams();
    Assert.Equal(fetchedGrams.Count, iteratedGrams.Count);
  }

  [Fact]
  public void TestSequenceIteratorMultipleTimes() {
    using var db = new UserDatabase(_testDbPath);

    var firstCount = db.Count();
    var secondCount = db.Count();

    Assert.Equal(firstCount, secondCount);
    Assert.Equal(3, firstCount);
  }

  [Fact]
  public void TestDatabaseOpenFailure() {
    Assert.Throws<DatabaseException>(() => new UserDatabase("/nonexistent/path/to/database.db"));
  }

  [Fact]
  public async Task TestAsyncSequenceIteration() {
    using var db = new UserDatabase(_testDbPath);

    var iteratedGrams = new List<Gram>();
    await foreach (var gram in db) {
      iteratedGrams.Add(gram);
    }

    var fetchedGrams = db.FetchGrams();
    Assert.Equal(fetchedGrams.Count, iteratedGrams.Count);
  }

  [Fact]
  public async Task TestAsyncSequenceMultipleIterations() {
    using var db = new UserDatabase(_testDbPath);

    var firstCount = 0;
    await foreach (var _ in db) {
      firstCount++;
    }

    var secondCount = 0;
    await foreach (var _ in db) {
      secondCount++;
    }

    Assert.Equal(firstCount, secondCount);
    Assert.Equal(3, firstCount);
  }

  [Fact]
  public void TestFindDatabases_ShouldReturnList() {
    var databases = UserDatabase.FindDatabases();
    // 不一定有安裝自然輸入法，但呼叫不應拋出錯誤
    Assert.NotNull(databases);
  }
}
