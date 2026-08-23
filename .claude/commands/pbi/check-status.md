# /pbi:check-status — チケット Status 整合性チェック

バックログチケットの `Status` プロパティが正しく設定されているかをチェックします。
チケット Type 別の有効 Status・廃止済み Status の使用・Done 時の Resolution 未設定を検出します。

## コマンド形式

```
/pbi:check-status [source]
```

### ソース指定方法

| 形式 | 説明 | 例 |
|------|------|-----|
| `#NUMBER` | GitHub Issue 番号 | `#1234` |
| （省略） | 対話モード（チケット情報を貼り付ける） | - |

> ℹ️ チケット ID フォーマットの実値は `.claude/config/ticket-system.json` の `ticketId` で定義する。他組織で流用する際は同 Config を書き換える。

---

## Status 定義（v3.2）

バックログ DB の有効 Status は以下の 6 種。それ以外（`廃止済_` プレフィックス付き等）は廃止済み。

| Status | 意味 |
|--------|------|
| To Do | 起票直後（未着手・未精査） |
| Refining | 精査中 |
| Refined | 精査完了 |
| In Progress | 作業中 |
| Reviewing | レビュー中 |
| Done | 完了 |

### チケット Type 別の有効 Status

| Type | 有効な Status |
|------|--------------|
| Story | Story Defined / In Sprint / Done |
| Task | To Do / Refining / Refined / In Progress / Reviewing / Done |
| SubTask | To Do / In Progress / Reviewing / Done |
| Tech / Needs / Bug / Request | To Do / Refining / Refined / In Progress / Reviewing / Done |

> **SubTask は Refining / Refined を使用しない**（4 状態のみ有効）

### Resolution プロパティ（Done 時に必須）

| Resolution 値 | 使用場面 |
|--------------|---------|
| Fixed | バグ修正・不具合対応 |
| Implemented | 機能実装・Task/SubTask の完了 |
| Unreproducible | バグが再現できなかった |
| Duplicated | 重複チケット |
| Won't Fix | 対応しないと判断 |
| Out of Scope | スコープ外と判断 |
| Investigation Done | 調査タスクの完了 |

---

## チェックルール

### チェック 1: 廃止済み Status の使用検出

`廃止済_` プレフィックスが付いた Status、または上記「有効 Status」に存在しない Status 値を検出する。

| 判定 | 条件 |
|------|------|
| ❌ 廃止済み | Status 値に `廃止済_` が含まれる |
| ❌ 無効値 | チケット Type の有効 Status 一覧に存在しない値が設定されている |
| ✅ 有効 | チケット Type の有効 Status 一覧内の値が設定されている |

### チェック 2: Done 時の Resolution 未設定

Status が `Done` のチケットに Resolution が設定されていない場合を検出する。

| 判定 | 条件 |
|------|------|
| ❌ Resolution 未設定 | Status = Done かつ Resolution が空 |
| ✅ 設定済み | Status = Done かつ Resolution に有効な値が設定されている |

### チェック 3: SubTask の Refining / Refined 使用検出

Type = SubTask のチケットに Refining または Refined が設定されている場合を検出する。

| 判定 | 条件 |
|------|------|
| ❌ 無効 Status | Type = SubTask かつ Status = Refining または Refined |
| ✅ 有効 | Type = SubTask かつ Status = To Do / In Progress / Reviewing / Done |

---

## ワークフロー

### Step 1: チケット情報の取得

ソース指定がある場合は `gh issue view` でチケットを取得する。
省略時は Type・Status・Resolution の入力を促す。

取得する情報:
- `Type`（Story / Task / SubTask / Tech / Needs / Bug / Request）
- `Status`（現在値）
- `Resolution`（現在値、空の場合もある）
- `Title`（チケット名）

### Step 2: チェックの実行

取得した情報をもとに、3 つのチェックルールを順に評価する。

### Step 3: 結果の出力

出力フォーマットに従い、チェック結果を報告する。

---

## 出力フォーマット

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 Status チェック結果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
チケット: #xxx「{タイトル}」
Type: {Type}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## チェック 1: Status の有効性

{✅ / ❌} Status: {現在値}

{❌ の場合}
  この Type（{Type}）の有効な Status は以下のとおりです：
  {有効 Status 一覧}
  → {推奨アクション}

## チェック 2: Resolution の設定（Done 時）

{✅ / ❌ / — ※Done でないためスキップ} Resolution: {現在値 or 未設定}

{❌ の場合}
  Status が Done の場合、Resolution の設定が必要です。
  用途に合わせて以下から選択してください：
  - Implemented（実装・Task完了）
  - Fixed（バグ修正）
  - Won't Fix / Out of Scope（対応しない場合）
  など

## チェック 3: SubTask の Status 制約

{✅ / ❌ / — ※SubTask でないためスキップ}

{❌ の場合}
  SubTask では Refining / Refined は使用できません。
  有効な Status: To Do / In Progress / Reviewing / Done

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
判定: {✅ 問題なし / ❌ 要修正 {N} 件}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 問題なしの場合

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
判定: ✅ 問題なし — Status の設定に問題は見つかりませんでした。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 対話モード

`/pbi:check-status` のみで実行した場合、以下を順番に確認する：

```
Status チェックモードを開始します。

チケットの Type を入力してください（Story / Task / SubTask / Tech / Needs / Bug / Request）:
> 

現在の Status を入力してください:
> 

Resolution の値を入力してください（未設定の場合は空 Enter）:
> 

（入力完了後、チェック結果を出力します）
```

---

## 根拠

- CLAUDE.md「GitHub Issue のルール — チケットのType体系」
- SubTask は 4 状態のみ有効（Refining/Refined はIssue系専用）
- Done 時は必ず Resolution を設定することがチーム運用ルール
