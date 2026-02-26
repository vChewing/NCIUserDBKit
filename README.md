# NCIUserDBKit

Swift: [![Swift](https://github.com/vChewing/NCIUserDBKit/actions/workflows/ci.yml/badge.svg)](https://github.com/vChewing/NCIUserDBKit/actions/workflows/ci.yml) [![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org) [![License: LGPL v3](https://img.shields.io/badge/License-LGPL%20v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)

自然輸入法 (NCI / GOING) 使用者資料庫讀取 Swift Package。

> **💻 C# 版**: `WinNT/` 目錄下含有 .NET 實作版本，詳見其自身的 [README.md](WinNT/README.md)。
>
> C#: [![.NET](https://github.com/vChewing/NCIUserDBKit/actions/workflows/ci.yml/badge.svg)](https://github.com/vChewing/NCIUserDBKit/actions/workflows/ci.yml) [![NuGet](https://img.shields.io/nuget/v/vChewing.Utils.NCIUserDBKit)](https://www.nuget.org/packages/vChewing.Utils.NCIUserDBKit) [![License: LGPL v3](https://img.shields.io/badge/License-LGPL%20v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)

## 目的

自然輸入法（Natural Chinese Input, codename `GOING`）的使用者資料庫 `profile.db` 為未加密的 SQLite 資料庫。本工具可直接讀取其中的使用者自訂詞條（`isCustom == 1`），方便使用者將詞條單獨備份留作他用。

## 功能

- 📖 讀取自然輸入法使用者自訂詞條（`isCustom == 1`）
- 🔤 注音符號讀音以 `-` 分隔，與 vChewing 格式相容
- 🔄 支援 `Sequence` 與 `AsyncSequence` 迭代
- 🔍 自動搜尋系統上安裝的自然輸入法使用者資料庫

## 資料庫結構

> ⚠︎ 本工具不處理由自然輸入法本身匯出的（可能受其著作權保護的）「PersonalPack.gox」私有資料格式。

自然輸入法的使用者資料庫 `profile.db` 包含 `profile` 資料表：

```sql
CREATE TABLE profile (
  keystrokes TEXT,     -- 注音讀音，以 - 分隔（如 ㄒㄧㄥ-ㄑㄩㄥˊ-ㄌㄧㄝˋ-ㄔㄜ）
  pattern TEXT,        -- 漢字詞語（如 星穹列車）
  hits INTEGER,        -- 使用次數
  isCustom INTEGER,    -- 是否為使用者自訂（1 = 自訂）
  timestamp INTEGER    -- 時間戳
)
```

有關該資料表「是否受網際智慧公司的智財權保護」，請洽本文末尾相關章節。

本工具僅提取 `isCustom == 1` 的條目，以 `timestamp` 排序。

## 資料庫位置

### macOS

```
~/Library/Application Support/GOING{v}/UserData/Going{v}/profile.db
```

其中 `v` 的範圍是 `[10, 99]`（閉區間）。

## 專案結構

```
NCIUserDBKit/
├── Package.swift                  # Swift Package 定義
├── CSQLite3/                      # SQLite3 C 模組（Linux 用）
│   └── Sources/CSQLite3/
│       ├── sqlite3.c
│       └── include/
│           └── sqlite3.h
├── Sources/
│   ├── NCIUserDBKit/              # 主要函式庫
│   │   ├── NCIUserDBKit.swift     # 模組定義
│   │   ├── Gram.swift             # 語料結構體
│   │   └── UserDatabase.swift     # 使用者資料庫讀取器
│   └── NCIUserDBCLI/              # 命令列工具 (ncidump)
│       └── main.swift
└── Tests/
    └── NCIUserDBKitTests/         # 單元測試 (Swift Testing)
        ├── GramTests.swift
        └── UserDatabaseTests.swift
```

## 系統需求

- Swift 6.1 或更新版本
- macOS 10.14+ / Linux

## 安裝

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/vChewing/NCIUserDBKit.git", from: "1.0.2")
]
```

```swift
// 在 target 中加入依賴
.target(
    name: "YourTarget",
    dependencies: ["NCIUserDBKit"]
)
```

## 建置

```bash
swift build
```

## 測試

```bash
swift test
```

## 使用範例

### 讀取資料庫

```swift
import NCIUserDBKit

// 開啟資料庫
let db = try UserDatabase(path: "/path/to/profile.db")
defer { db.close() }

// 讀取所有使用者自訂詞條
let grams = try db.fetchGrams()
for gram in grams {
    print("\(gram.current)\t\(gram.keyArray.joined(separator: "-"))")
}
```

### 尋找已安裝的資料庫

```swift
let databases = UserDatabase.findDatabases()
for path in databases {
    print("找到資料庫：\(path)")
}
```

### 使用迭代器

```swift
// Sequence
for gram in db {
    print(gram.current)
}

// AsyncSequence
for await gram in db {
    print(gram.current)
}
```

## 命令列工具 (ncidump)

```bash
# 顯示指定資料庫的所有使用者自訂詞條
swift run ncidump dump /path/to/profile.db

# 搜尋已安裝的自然輸入法資料庫
swift run ncidump find

此指令會在下列位置搜尋

* macOS: `~/Library/Application Support/GOING{10-99}/UserData/Going{N}/profile.db`
* Windows: `%APPDATA%\Going{10-99}\profile.db`

即便您在非本平台運行也不會失敗。
# 匯出所有找到的使用者自訂詞條
swift run ncidump dumpall
```

## 授權

本專案以 [LGPL-3.0-or-later](LICENSES/preferred/LGPL-3.0-or-later) 授權釋出。

> 「'Natural Chinese Input', 'GOING', and '網際智慧' are trademarks of their respective owners. This project is not affiliated with or endorsed by IQ Technology.

------

## 與著作權疑慮有關的說明

### 1. 這個專案是否涉嫌對 DRM 的規避？

- 該專案所專門讀取的 SQLite 資料庫（`profile.db`）**未加密**，不存在「技術保護措施」。
- 本工具僅讀取已平文存儲的使用者資料。
- 該專案不處理由自然輸入法本身匯出的（可能受其著作權保護的）「PersonalPack.gox」私有資料格式。

### 2. DMCA 安全港適用於這個專案嗎？

- 本工具僅讀取**使用者自訂詞條**（isCustom == 1）。
- 目的為**使用者資料備份與遷移**，符合 DMCA §1201(f) 對互操作性的保護（另，使用者對自身資料的匯出亦符合 §1201(j) 的精神）。
- 不提供或協助規避任何技術保護措施。
- 本專案為**互操作性研究**的一部分，因為：
  - 幫助使用者從一個 IME (自然輸入法) 遷移到其他 IME (vChewing、fcitx5-mcbopomofo 等)、或以 txt 的形式備份原始資料。
  - 程式讀取的是「使用者自訂詞條」的讀音與字詞，而非軟體程式碼或智財。
  - 符合 DMCA §1201(f) 對互操作性的保護。
- 該專案為開放原始碼的免費工具，不以商業獲利為目的。

另：使用者對自己創建的片語資料享有完全所有權，「匯出自己的資料」屬於個人合理使用範疇。敝專案不改變原始資料，只是提供更便利的匯出介面。
使用者完全可以用 sqlite3 CLI 自行達成相同結果：

```
sqlite3 profile.db "SELECT * FROM profile WHERE isCustom=1"
```

會在終端機列印這種格式的內容：

```
~/Library/Application Support/GOING11/UserData/Going11> sqlite3 profile.db "SELECT * FROM profile WHERE isCustom=1"
ㄍㄨㄥ-ㄒㄧㄤˋ|公象|1|1|1650506935
ㄊㄧˊ-ㄍㄨㄥ|提供|1|1|1650506949
ㄒㄧㄤˋ-ㄕˋ|像是|1|1|1650506953
ㄒㄧㄥ-ㄑㄩㄥˊ-ㄌㄧㄝˋ-ㄔㄜ|星穹列車|1|1|1771585331
```

敝工具只是簡化了這個過程。

#### 2a. 本專案的商業性質

- 本專案為開源免費軟體，以 LGPL-3.0-or-later 授權釋出。
- 維護者不以商業獲利為目的。
- 使用者可自由複製、修改、分發本工具。

### 3. 這個 SQLite 資料庫結構受著作權保護嗎？

[Digital Curation Centre (數位典藏策展中心) 的這篇文章](https://www.dcc.ac.uk/guidance/briefing-papers/legal-watch-papers/ipr-databases)給了一個合理的解釋：

> Copyright is the intellectual property right that protects the expression of ideas or information. There is often confusion around the subsistence of copyright in a database. A database may attract copyright protection but only in certain limited circumstances. Firstly, the structure of a database may be protected if, by reason of the selection or arrangement of the contents, it constitutes the author's own intellectual creation. Secondly, depending on what is contained in the database, copyright might also exist independently in the contents of the database (for example, a database of images where each of the images would attract its own copyright protection as an artistic work).

翻譯：

> 著作權是一種保護思想或資訊之「表達形式」的智慧財產權。關於資料庫是否享有著作權保護，實務上常有混淆。資料庫在某些特定且有限的情況下，可能受到著作權保護。首先，如果資料庫之結構，基於其內容之選擇或編排方式，而構成作者自身之智力創作成果（author's own intellectual creation），則該結構可能受到著作權保護。其次，視資料庫所包含之內容而定，資料庫中的內容本身亦可能獨立享有著作權。例如，一個圖片資料庫中，每一張圖片若本身屬於藝術著作，則各該圖片可分別受到著作權保護。

前文提到的 SQLite 資料表架構旨在統計「注音讀音」「漢字詞語」「使用次數」「是否為使用者自訂」以及追加的時間戳。

> 給資料內容追加時間戳的行為，是軟體工業從業者們在資料表結構設計時的常見操作，恐很難主張獨創性。

剩下的內容呢，雖然「使用次數」被排除在敝工具最終匯出的內容範圍之外，但咱們最好結合看一下姜天戩的菸草注音的原始碼當中對 `profile` 的架構定義：

https://github.com/vChewing/OVIMTobacco-Backup/blob/bf0e7dc92460b26502b75cad6938d1ebc55cf81e/Tobacco/Profile.cpp#L1-L27

```cpp
#include "Profile.h"

using namespace std;

ProfileId::ProfileId(const string& theKeystrokes, const string& thePattern) :
  keystrokes(theKeystrokes), pattern(thePattern)
{}

ProfileId::ProfileId(const ProfileId& theId) :
  keystrokes(theId.keystrokes), pattern(theId.pattern)
{}

bool ProfileId::operator==(const ProfileId& rhsProfileId)
{
  return
    keystrokes == rhsProfileId.keystrokes &&
      pattern == rhsProfileId.pattern;
}

Profile::Profile(const ProfileId& theId) :
  id(theId), hitRate(0), isCustom(false)
{}

Profile::Profile(const Profile& theProfile) :
  id(theProfile.id), hitRate(theProfile.hitRate),
  isCustom(theProfile.isCustom)
{}
```

由該段原始碼可得知一個 Profile 需要「注音讀音」「漢字詞語」「使用次數」「是否為使用者自訂」這四個資料欄位。

### 結論：

- 台澎金馬： 依據《著作權法》第二章第 7 條及相關實務見解，資料庫若要受著作權保護，須就其「內容之選擇」或「編排」具有創作性（編輯著作）。
- 中國大陸： 依據《中華人民共和國著作權法》第二章第二節第十四條　【匯編作品著作權的歸屬】匯編若干作品、作品的片段或者不構成作品的數據或者其他材料，對其內容的選擇或者編排體現獨創性的作品，為匯編作品，其著作權由匯編人享有，但行使著作權時，不得侵犯原作品的著作權。

前文提到的 SQLite 資料表架構旨在統計「注音讀音」「漢字詞語」「使用次數」「是否為使用者自訂」以及追加的時間戳。

這種單純基於功能性需求（Functionality）而設計的欄位組合，屬於軟體開發中的通用慣例（Scènes à faire），缺乏著作權法所要求的「獨創性」表達，因此難以主張受著作權保護。

$ EOF.
