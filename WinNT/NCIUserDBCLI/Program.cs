// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

using NCIUserDBKit;

if (args.Length < 1) {
  PrintUsage();
  return 1;
}

try {
  return args[0].ToLowerInvariant() switch {
    "dump" => HandleDump(args),
    "find" => HandleFind(),
    "dumpall" => HandleDumpAll(),
    "--help" or "-h" => PrintUsageAndReturn(),
    _ => HandleUnknown(args[0])
  };
} catch (Exception ex) {
  Console.Error.WriteLine($"錯誤：{ex.Message}");
  return 1;
}

static void PrintUsage() {
  var programName = Path.GetFileName(Environment.ProcessPath) ?? "ncidump";
  Console.WriteLine($"""
        自然輸入法 (NCI / GOING) 使用者資料庫工具

        用法: {programName} <指令> [選項]

        指令:
          dump <資料庫路徑>           顯示資料庫中的所有使用者自訂詞彙
          find                        搜尋系統上的自然輸入法使用者資料庫
          dumpall                     匯出系統上找到的所有使用者自訂詞彙

        選項:
          -h, --help                  顯示此說明

        範例:
          {programName} dump %appdata%\Going11\profile.db
          {programName} find
          {programName} dumpall
        """);
}

static int PrintUsageAndReturn() {
  PrintUsage();
  return 0;
}

static int HandleUnknown(string cmd) {
  Console.Error.WriteLine($"未知的指令: {cmd}");
  PrintUsage();
  return 1;
}

static void ShowData(string dbPath) {
  using var db = new UserDatabase(dbPath);
  var grams = db.FetchGrams();

  Console.WriteLine($"=== 使用者自訂詞條 (isCustom == 1, 依 timestamp 排序) ===");
  Console.WriteLine($"共 {grams.Count} 筆");
  foreach (var gram in grams) {
    var reading = string.Join("-", gram.KeyArray);
    Console.WriteLine($"  {gram.Current}\t{reading}\t(hits={gram.Hits}, ts={gram.Timestamp})");
  }
}

static int HandleDump(string[] args) {
  if (args.Length < 2) {
    Console.Error.WriteLine("用法: ncidump dump <資料庫路徑>");
    return 1;
  }

  var dbPath = args[1];

  if (!File.Exists(dbPath)) {
    Console.Error.WriteLine($"錯誤：找不到檔案 {dbPath}");
    return 1;
  }

  ShowData(dbPath);
  return 0;
}

static int HandleFind() {
  var databases = UserDatabase.FindDatabases();

  if (databases.Count == 0) {
    Console.WriteLine("未找到任何自然輸入法使用者資料庫。");
    Console.WriteLine(@"搜尋範圍：%appdata%\Going{10-99}\profile.db");
    return 0;
  }

  Console.WriteLine($"找到 {databases.Count} 個自然輸入法使用者資料庫：");
  foreach (var path in databases) {
    Console.WriteLine($"  {path}");
  }
  return 0;
}

static int HandleDumpAll() {
  var databases = UserDatabase.FindDatabases();

  if (databases.Count == 0) {
    Console.WriteLine("未找到任何自然輸入法使用者資料庫。");
    return 0;
  }

  foreach (var path in databases) {
    Console.WriteLine($"\n--- {path} ---");
    ShowData(path);
  }
  return 0;
}
