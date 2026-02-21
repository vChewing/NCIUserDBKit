// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

using System.Collections;
using System.Runtime.InteropServices;

using Microsoft.Data.Sqlite;

namespace NCIUserDBKit;

/// <summary>
/// 自然輸入法使用者資料庫讀取器
/// </summary>
/// <remarks>
/// <para>
/// 自然輸入法的使用者資料庫 (profile.db) 為未加密的 SQLite 資料庫，
/// 包含 profile 資料表：
/// </para>
/// <code>
/// CREATE TABLE profile (
///   keystrokes TEXT,
///   pattern TEXT,
///   hits INTEGER,
///   isCustom INTEGER,
///   timestamp INTEGER
/// )
/// </code>
/// <para>
/// 本工具僅提取 isCustom == 1 的條目（使用者手動加詞），
/// 並以 timestamp 排序。
/// </para>
/// </remarks>
public sealed class UserDatabase : IDisposable, IEnumerable<Gram>, IAsyncEnumerable<Gram> {
  /// <summary>
  /// 自然輸入法 codename
  /// </summary>
  public const string Codename = "GOING";

  /// <summary>
  /// 支援的最小版本號
  /// </summary>
  public const int MinVersion = 10;

  /// <summary>
  /// 支援的最大版本號
  /// </summary>
  public const int MaxVersion = 99;

  private readonly SqliteConnection _connection;
  private readonly System.Threading.Lock _lock = new();
  private bool _disposed;

  // MARK: - Constructors

  /// <summary>
  /// 開啟資料庫
  /// </summary>
  /// <param name="path">資料庫檔案路徑</param>
  public UserDatabase(string path) {
    var connectionString = new SqliteConnectionStringBuilder {
      DataSource = path,
      Mode = SqliteOpenMode.ReadOnly
    }.ToString();

    _connection = new SqliteConnection(connectionString);

    try {
      _connection.Open();
    } catch (SqliteException ex) {
      throw new DatabaseException($"Failed to open database: {ex.Message}", ex);
    }
  }

  // MARK: - Static Methods

  /// <summary>
  /// 在 Windows 上尋找所有自然輸入法使用者資料庫
  /// </summary>
  /// <returns>找到的資料庫檔案路徑陣列</returns>
  public static List<string> FindDatabases() {
    var results = new List<string>();
    var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
    if (string.IsNullOrEmpty(appData)) return results;

    for (var version = MinVersion; version <= MaxVersion; version++) {
      var dbPath = Path.Combine(appData, $"Going{version}", "profile.db");
      if (File.Exists(dbPath)) {
        results.Add(dbPath);
      }
    }

    return results;
  }

  // MARK: - Public Methods

  /// <summary>
  /// 讀取所有使用者自訂詞條（isCustom == 1），以 timestamp 排序
  /// </summary>
  public List<Gram> FetchGrams() {
    lock (_lock) {
      ThrowIfDisposed();

      const string sql = """
        SELECT keystrokes, pattern, hits, timestamp
        FROM profile
        WHERE isCustom = 1
        ORDER BY timestamp
        """;
      var results = new List<Gram>();

      using var command = new SqliteCommand(sql, _connection);
      using var reader = command.ExecuteReader();

      while (reader.Read()) {
        var keystrokes = reader.GetString(0);
        var pattern = reader.GetString(1);
        var hits = reader.GetInt32(2);
        var timestamp = reader.GetInt64(3);

        results.Add(Gram.CreateFromKeystrokes(keystrokes, pattern, hits, timestamp));
      }

      return results;
    }
  }

  // MARK: - IEnumerable<Gram>

  /// <inheritdoc/>
  public IEnumerator<Gram> GetEnumerator() {
    return new GramEnumerator(this);
  }

  /// <inheritdoc/>
  IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

  // MARK: - IAsyncEnumerable<Gram>

  /// <inheritdoc/>
  public async IAsyncEnumerator<Gram> GetAsyncEnumerator(CancellationToken cancellationToken = default) {
    await foreach (var gram in IterateGramsAsync(cancellationToken)) {
      yield return gram;
    }
  }

  private async IAsyncEnumerable<Gram> IterateGramsAsync(
      [System.Runtime.CompilerServices.EnumeratorCancellation] CancellationToken cancellationToken = default) {
    const string sql = """
      SELECT keystrokes, pattern, hits, timestamp
      FROM profile
      WHERE isCustom = 1
      ORDER BY timestamp
      """;
    await using var command = new SqliteCommand(sql, _connection);
    await using var reader = await command.ExecuteReaderAsync(cancellationToken);

    while (await reader.ReadAsync(cancellationToken)) {
      var keystrokes = reader.GetString(0);
      var pattern = reader.GetString(1);
      var hits = reader.GetInt32(2);
      var timestamp = reader.GetInt64(3);

      yield return Gram.CreateFromKeystrokes(keystrokes, pattern, hits, timestamp);
    }
  }

  // MARK: - Internal Methods for Iterator

  internal SqliteDataReader ExecuteReader(string sql) {
    lock (_lock) {
      ThrowIfDisposed();
      var command = new SqliteCommand(sql, _connection);
      return command.ExecuteReader();
    }
  }

  // MARK: - IDisposable

  private void ThrowIfDisposed() {
    ObjectDisposedException.ThrowIf(_disposed, this);
  }

  /// <inheritdoc/>
  public void Dispose() {
    if (_disposed) return;

    lock (_lock) {
      _connection.Dispose();
      _disposed = true;
    }
  }

  // MARK: - GramEnumerator

  private sealed class GramEnumerator : IEnumerator<Gram> {
    private readonly UserDatabase _database;
    private SqliteDataReader? _reader;
    private Gram? _current;
    private bool _initialized;

    public GramEnumerator(UserDatabase database) {
      _database = database;
    }

    public Gram Current => _current ?? throw new InvalidOperationException("No current element");

    object IEnumerator.Current => Current;

    public bool MoveNext() {
      if (!_initialized) {
        const string sql = """
          SELECT keystrokes, pattern, hits, timestamp
          FROM profile
          WHERE isCustom = 1
          ORDER BY timestamp
          """;
        _reader = _database.ExecuteReader(sql);
        _initialized = true;
      }

      if (_reader is null) return false;

      if (_reader.Read()) {
        var keystrokes = _reader.GetString(0);
        var pattern = _reader.GetString(1);
        var hits = _reader.GetInt32(2);
        var timestamp = _reader.GetInt64(3);

        _current = Gram.CreateFromKeystrokes(keystrokes, pattern, hits, timestamp);
        return true;
      }

      _reader.Dispose();
      _reader = null;
      return false;
    }

    public void Reset() {
      _reader?.Dispose();
      _reader = null;
      _initialized = false;
      _current = null;
    }

    public void Dispose() {
      _reader?.Dispose();
      _reader = null;
    }
  }
}

/// <summary>
/// 資料庫錯誤
/// </summary>
public class DatabaseException : Exception {
  /// <summary>
  /// 以指定訊息初始化資料庫錯誤
  /// </summary>
  public DatabaseException(string message) : base(message) {
  }

  /// <summary>
  /// 以指定訊息和內部例外初始化資料庫錯誤
  /// </summary>
  public DatabaseException(string message, Exception innerException)
      : base(message, innerException) {
  }
}
