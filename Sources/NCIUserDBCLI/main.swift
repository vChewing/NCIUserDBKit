// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import NCIUserDBKit

// MARK: - CLI Implementation

func printUsage() {
  let programName = (CommandLine.arguments[0] as NSString).lastPathComponent
  print(
    """
    自然輸入法 (NCI / GOING) 使用者資料庫工具

    用法: \(programName) <指令> [選項]

    指令:
      dump <資料庫路徑>           顯示資料庫中的所有使用者自訂詞彙
      find                        搜尋系統上的自然輸入法使用者資料庫
      dumpall                     匯出系統上找到的所有使用者自訂詞彙

    選項:
      -h, --help                  顯示此說明

    範例:
      \(programName) dump ~/Library/Application\\ Support/GOING11/UserData/Going11/profile.db
      \(programName) find
      \(programName) dumpall
    """
  )
}

func showData(dbPath: String) {
  do {
    let db = try NCIUserDBKit.UserDatabase(path: dbPath)
    let grams = try db.fetchGrams()

    print("=== 使用者自訂詞條 (isCustom == 1, 依 timestamp 排序) ===")
    print("共 \(grams.count) 筆")
    for gram in grams {
      let reading = gram.keyArray.joined(separator: "-")
      print("  \(gram.current)\t\(reading)\t(hits=\(gram.hits), ts=\(gram.timestamp))")
    }
  } catch {
    print("無法讀取資料: \(error.localizedDescription)")
  }
}

func handleDump(args: [String]) -> Int32 {
  guard args.count >= 2 else {
    print("用法: ncidump dump <資料庫路徑>")
    return 1
  }

  let dbPath = args[1]

  guard FileManager.default.fileExists(atPath: dbPath) else {
    print("錯誤：找不到檔案 \(dbPath)")
    return 1
  }

  showData(dbPath: dbPath)
  return 0
}

func handleFind() -> Int32 {
  let databases = NCIUserDBKit.UserDatabase.findDatabases()

  if databases.isEmpty {
    print("未找到任何自然輸入法使用者資料庫。")
    print("搜尋範圍：~/Library/Application Support/GOING{10-99}/UserData/Going{10-99}/profile.db")
    return 0
  }

  print("找到 \(databases.count) 個自然輸入法使用者資料庫：")
  for url in databases {
    print("  \(url.path)")
  }
  return 0
}

func handleDumpAll() -> Int32 {
  let databases = NCIUserDBKit.UserDatabase.findDatabases()

  if databases.isEmpty {
    print("未找到任何自然輸入法使用者資料庫。")
    return 0
  }

  for url in databases {
    print("\n--- \(url.path) ---")
    showData(dbPath: url.path)
  }
  return 0
}

func main() -> Int32 {
  let args = CommandLine.arguments

  guard args.count >= 2 else {
    printUsage()
    return 1
  }

  switch args[1].lowercased() {
  case "dump":
    return handleDump(args: Array(args.dropFirst()))
  case "find":
    return handleFind()
  case "dumpall":
    return handleDumpAll()
  case "--help", "-h":
    printUsage()
    return 0
  default:
    print("未知的指令: \(args[1])")
    printUsage()
    return 1
  }
}

exit(main())
