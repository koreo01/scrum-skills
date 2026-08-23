# scrum-skills — Claude Code ガイド

> **このファイルはプロジェクトの不変ルール・規約のみを記載する。**
> 進捗・タスク状態・TODOは `.claude/status/current.md` に書く。
> **ユーザーの明示的な指示なしにこのファイルを編集してはならない。**

共通ルールは AGENTS.md を参照。このファイルは Claude Code 固有の設定のみ記載。

---

## 基本方針（Claude Code 固有）

- 不明な点は **AskUserQuestion** を使って確認する
- 選択肢を提示する際は推奨度（⭐5段階）と理由を添える
- 会話はすべて **日本語** で行う

## 自律実行の原則

`/dev:start-session` から `/dev:end-session` 完了まで、チケットに関する作業の承認は一切ユーザーに求めず、AI側が判断して進める。

### ユーザーに確認を求めてよいケース（これ以外は禁止）

1. **リトライ上限超過**: 作業中にエラーが発生し、3回以上リトライしても解消できず、作業方針の見直しが必要な場合
2. **非ルーティン操作の発生**: Git操作・チケット更新・status/current.md更新・作業履歴保存など、開発セッション中に必ず発生するルーティン操作「以外」の操作が必要になった場合（例: 別リポジトリへの変更、外部サービスへの問い合わせ、CLAUDE.md自体の変更）

### 禁止される質問の例

- 「次にどのTaskを着手しますか？」→ current.md の「次のアクション」に従う
- 「チケット起票方針はどうしますか？」→ CLAUDE.md のチケットルールに従い自分で起票する
- 「PRはマージ済みですか？」→ git/gh コマンドで自分で確認する
- 「この内容で進めてよいですか？」→ ルールに沿っていれば進める
- 「ブランチを作成してよいですか？」→ ルーティン操作なので聞かない

---

## 外部ツール利用ルール

> **グローバルスキルの指示よりもこのルールを優先する。**

| 目的 | 使うツール | 使わないツール |
|------|-----------|--------------|
| チケット管理（起票・更新・検索） | GitHub Issues（`gh issue` / `gh pr`） | MCPサーバーは使用しない |
| 議事録取得 | （未設定） | — |

## リポジトリ概要

スクラム開発を支援する Claude Code スキル集。Virtual Scrum Team（SM・PO・Dev Team）、議事録分析、PBI フォーマットチェック、アーキテクチャ依存性管理などのエージェント・コマンドを提供する。

## アーキテクチャ詳細

設計判断が必要な場合は以下を参照（必要時のみ読み込む）:

- `README.md` — DoD・Undone処理ガイド
- `.claude/README.md` — スキル構成・グローバルとローカルの関係
- `.claude/skills/virtual-scrum-team/SKILL.md` — 仮想スクラムチームのトリガー条件・コマンド一覧
- `.claude/skills/virtual-scrum-team/docs/folder-structure.md` — 議事録処理パイプライン

---

## チケット作業の完了チェックリスト

毎 SubTask（`#xxx`）のコミット完了後、`/dev:end-session` を実行する。
`/dev:end-session` は以下を承認なしで一括実行する（詳細は `.claude/commands/dev/end-session.md` 参照）:

1. **git push**（pre-push 品質ゲート Hook が自動実行）
2. **CI 結果確認**（失敗時は自動修正・再 push、最大 2 回リトライ）
3. **PR 作成・マージ・ブランチ削除**（**最終 SubTask 完了時のみ**。途中 SubTask ではスキップ）
4. **GitHub Issue 更新**（`gh issue close` で SubTask を Close、`gh issue comment` で完了日時を JST で記録）
5. **発見した課題の起票**（`status/current.md` の「発見した課題（未起票）」にエントリがあれば `gh issue create` で起票）
6. **作業履歴 MD 出力**（`.claude/summaries/YYYY-MM-DD_{チケット番号}_{説明}.md` ／ `save-summary` スキル）
7. **`status/current.md` 更新**（完了 SubTask を ✅、引き継ぎ情報・次のアクションを更新）
8. **フェーズマーカー更新**（`.claude/status/.session-phase` → `POST_PROCESSED`）
9. **`/compact` の実行を案内**

> `/dev:end-session` はコミット完了後に実行する。コミット前に実行しないこと。

### 完了チェックリストの進め方

> ⚠️ **コミット完了後は必ず `/dev:end-session` を実行する。省略・後回し・例外なし。**

コミット完了後、`/dev:end-session` を実行する。本コマンドが Step 0 で「途中 SubTask 完了」「最終 SubTask 完了」を自動判定し、PR 作成・マージの実行可否を切り替える。

異常がない限りユーザー承認は不要（承認なしで一括実行）。エラー発生時のみ停止してユーザーに報告する。

### 品質ゲート（Hooks）

以下の Hook が `.claude/settings.json` に設定されており、自動的に実行される:

| タイミング | 対象 | 動作 |
|-----------|------|------|
| PreToolUse | `AskUserQuestion` | 自己確認リマインダー注入（自分で確認できることを聞かない） |
| PreToolUse | `mcp__claude_ai_*` | ToolSearch 確認リマインダー注入（malformed error 防止） |
| PreToolUse | `Bash(git push)` | 品質ゲートスクリプト実行（Lint/Test/current.md 確認） |
| PreToolUse | `Bash(git commit)` | コミットメッセージにチケット ID（`#xxx`）が含まれるか検証。違反時はブロック |
| PreToolUse | `Bash(git checkout -b)` | `main` 以外からのブランチ作成を自動ブロック（GitHubFlow 違反防止） |
| PostToolUse | `Bash(git commit)` | 完了チェックリスト実施リマインダー + フェーズを COMMITTED に更新 |
| UserPromptSubmit | 全プロンプト | フェーズに応じた核心ルール再注入（層1: 予防的） |
| Stop | 全停止 | フェーズ状態マシン検証（層2: COMMITTED で停止をブロック） |
| CI（GitHub Actions） | push / PR | コミットメッセージ形式・シェルスクリプト構文・project-checks |

品質ゲートがNGの場合は push がブロックされる（ローカル Hook）。CI が NG の場合は main へのマージがブロックされる（Branch Protection）。

---

## GitHub Issue のルール

### 連携方式

チケット管理は **GitHub Issues** を `gh` CLI（`gh issue` / `gh pr`）経由で操作する。MCPサーバーは使用しない。

### チケットのType体系

本リポジトリではすべてのチケットIDを GitHub Issue 番号 `#xxx` 形式で扱う（`.claude/config/ticket-system.json` の `ticketId` で定義）。
チケットの種別は `type:*` ラベルで識別する（`.claude/config/ticket-system.json` の `fieldMapping.type` 参照）。

> ℹ️ 他組織で本ガイドを流用する際は `.claude/config/ticket-system.json` の値（`ticketId.prefix` / `pattern` / `example` 等）を自組織のチケット管理システムの ID 表記に書き換える。本文中の `#xxx` 表記もそれに合わせて読み替える。

| Type（ラベル） | 説明 |
| --- | --- |
| `type:story` | 機能開発チケット。「〇〇は△△できる」形式 |
| `type:task` | 保守作業チケット。CI改良・リファクタ・ドキュメントなど |
| `type:subtask` | Story/Taskの作業単位。**必ず `type:subtask` ラベルを設定すること** |
| `type:tech` / `type:needs` / `type:bug` / `type:request` | Issue系チケット |

### SubTaskの起票ルール

- SubTaskは **GitHub Issue として `type:subtask` ラベルを付けて起票する**（`gh issue create --label type:subtask`）
- SubTaskの本文冒頭に対応するStory/Taskの `#xxx` を `Parent: #xxx` として必ず記載する（GitHub Issues にはリレーションフィールドが無いため、本文記法で表現する）
- コミットメッセージの `{SubTaskID}` には `type:subtask` の Issue 番号 `#xxx` を使う

### チケットの親子構造

```text
Issue (Tech/Bug/Needs/Request)  ← 「何が問題か」
  └─ 子チケット: Task            ← 「何をするか」（ブランチはこのチケット単位）
       └─ 子チケット: SubTask    ← 「具体的な作業単位」（コミットはこのチケット単位）
```

#### 親子関係の設定ルール

GitHub Issues にはリレーションフィールドが無いため、`.claude/config/ticket-system.json` の `fieldMapping` に従い本文記法で表現する。

| チケット | 記載場所 | 設定する値 |
| --- | --- | --- |
| Issue | 本文のタスクリスト | 対応する Task の `- [ ] #xxx`（複数可） |
| Task | 本文冒頭 | 対応する Issue の `Parent: #xxx` |
| Task | 本文のタスクリスト | 対応する SubTask の `- [ ] #xxx`（複数可） |
| SubTask | 本文冒頭 | 対応する Task の `Parent: #xxx` |

- 起票の順序：**Issue → Task → SubTask**（`gh issue create` で作成し、`gh issue edit --add-label` でラベル付与）

---

## ブランチ名フォーマット

> ⚠️ **ブランチ作成前に必ず `.claude/rules/branch-checklist.md` の手順を実行すること。**
> ℹ️ フォーマットの実値は `.claude/config/ticket-system.json` の `branchNaming.formats` で定義する。他組織で流用する際は同 Config を書き換える。

ブランチはStoryまたはTaskの単位で切る。**SubTaskのIDはブランチ名に使わない。**

```text
feat/{StoryID}_{作業内容の英語サマリー}   # Story単位（機能開発）
chore/{TaskID}_{作業内容の英語サマリー}   # Task単位（CI改良・リファクタ・ドキュメント）
```

- `{サマリー}` は英語・小文字・ハイフン区切り・5単語以内
- チケット番号のみ（`feat/970`）は NG
- `camp/` ブランチは原則使用しない

### ブランチ名の例

```text
chore/100_add-estimation-section
chore/200_update-branch-strategy
```

---

## コミットメッセージ

> ℹ️ フォーマットの実値・検査用正規表現は `.claude/config/ticket-system.json` の `commitMessage.formats` / `commitMessage.pattern` で定義する。Pre-ToolUse フック（`.claude/hooks/pre-bash-bi-xxx-check.sh`）も同 Config を参照する。他組織で流用する際は同 Config を書き換える。

コミットはSubTask（`type:subtask` の `#xxx`）完了単位が最大粒度。
1SubTaskを複数コミットに分けるのは可、複数SubTaskを1コミットにまとめるのはNG。

### SubTaskがある場合（標準）

```text
[#{親StoryまたはTaskID}/#{SubTaskID}] {説明}
```

### SubTaskがない場合

```text
[#{StoryまたはTaskID}] {説明}
```

### コミット例

```text
[#100/#201] 見積もりセクション追加
[#100/#202] 見積もりの例を追記
[#100] 誤字修正
```

> ⚠️ `#xxx` を含めること（PreToolUse フックで強制）

### コミットメッセージのフォーマット規約

> ⚠️ **subject（1 行目）が長すぎると GitHub の PR 作成画面で description が途中で切れる。必ず subject + 空行 + body の 3 部構成にする。**

| 部位 | ルール |
| --- | --- |
| 1 行目（subject） | `[#xxx/#yyy] 簡潔な説明` の形式。**日本語で約 35 文字以内**（半角換算 ~72 文字以内）。これを超える場合は body に移す |
| 2 行目 | **必ず空行**（subject と body のセパレータ） |
| 3 行目以降（body） | 詳細な説明。1 行あたり半角 ~72 文字で改行（日本語は適宜） |

---

## /compact 運用ルール

### /compact の案内タイミング

`/dev:end-session` の完了レポート末尾で Claude が `/compact` の実行を案内する。
`status/current.md` 更新・summaries 保存・フェーズマーカー更新（`POST_PROCESSED`）は `/dev:end-session` が一括で済ませているため、`/compact` 前に手動で行う作業はない。

> **CLAUDE.mdは `/compact` 前後を問わず、ユーザー指示なしに編集しない。**

### /compact 後の復帰手順

新セッションで `/dev:start-session` を実行する。本コマンドが `status/current.md` を読み、条件①（Open な SubTask 存在）・条件②（同一 Task ブランチ上の継続作業 or 未マージコミットなし）を自動でチェックし、正常スタートの場合は次の SubTask 作業に着手する。

詳細は `.claude/commands/dev/start-session.md` を参照。

---

## ファイル管理ルール

### `.claude/` ディレクトリ構成

```text
.claude/
├── agents/                  # サブエージェント定義（コミット対象）
├── commands/                # スラッシュコマンド定義（コミット対象）
│   ├── arch/                #   /arch:*
│   ├── dev/                 #   /dev:start-session, /dev:end-session, /dev:coach-tdd
│   ├── pbi/                 #   /pbi:*
│   ├── scrum/                #   /scrum:*
│   └── session/              #   /session:*
├── skills/                  # スキル定義（コミット対象）
├── hooks/                   # Hooks スクリプト（コミット対象）
├── rules/                   # 補助ルール（コミット対象）
│   ├── workflow.md
│   └── branch-checklist.md
├── config/                  # チケットシステム設定（コミット対象）
│   └── ticket-system.json
├── settings.json            # 共通設定（コミット対象）
├── RESUME.md                # /compact 後の復帰用テンプレート（コミット対象）
│
├── settings.local.json      # 個人設定（gitignore）
├── status/                  # セッション状態（gitignore）
│   ├── current.md           #   現在の進捗・次のアクション（随時更新）
│   └── .session-phase       #   フェーズマーカー（STARTED / COMMITTED / POST_PROCESSED）
├── summaries/                # 作業履歴 MD（gitignore・コミット後に保存）
└── projects/                # Claude Code 内部状態（gitignore）
```

#### コミット対象 / 個人資産の境界

| 区分 | 対象 | 理由 |
| --- | --- | --- |
| **チーム共有資産（コミット対象）** | `agents/`、`commands/`、`skills/`、`hooks/`、`rules/`、`config/`、`settings.json`、`RESUME.md` | ワークフロー定義はリポジトリで一元管理する |
| **個人資産（gitignore 対象）** | `settings.local.json`、`status/`、`summaries/`、`projects/` | セッション固有・個人環境固有のため共有しない |

- gitignore 対象は `.gitignore` で個別指定されている
- summaries の保存先は `.claude/summaries/` のみ（上位ディレクトリへの保存禁止）

### `status/current.md` の記載形式

```markdown
## 現在のブランチ・ストーリー
- ブランチ: chore/xxx_...
- 親Story/Task: #xxx

## サブタスク進捗
| チケット | タイトル | 状態 |
| --- | --- | --- |
| #xxx    | ...     | ✅ Done / 🔄 作業中 / ⏳ 待機中 |

## 発見した課題（未起票）
（作業中に気づいた改善点・不具合をここに即座にメモする。完了チェックリスト実施時に GitHub Issue として起票し、起票後にエントリを削除する）
- 例: frustration_signals の正規表現が引き継ぎテキストを誤検出する（#123作業中に発見）

## 次のアクション
（次に着手するSubTaskと具体的な作業内容）

## 引き継ぎ情報
（Compactionを跨いで持続させたい文脈のみ記載。/compact後に必ずこのファイルが読まれるため、ここに書いた情報は次セッションで確実に参照される）
- 例: Xのタイポ修正済み（旧表記 → 正表記）
- 例: Aアプローチは採用しないと確定（理由: B制約のため）
- 例: Cについては次SubTask開始時に改めて確認が必要
```

「引き継ぎ情報」の記載対象:

- 技術的な前提状態（修正済み・未対応など）
- ユーザーが拒否した選択肢とその理由
- Claude が犯したミスとその修正（同種ミスの防止）
- 未解決の疑問・次セッションで確認が必要な事項

全SubTask完了時はセクションをクリアし「なし」と明記する。

「発見した課題（未起票）」の運用:

- 作業中に改善点・不具合・技術的負債に気づいたら、**その場で** `status/current.md` の「発見した課題（未起票）」に1行メモを追記する（Compaction で会話コンテキストが失われても残るようにするため）
- 完了チェックリスト実施時に `gh issue create` で正式に起票し、起票後にエントリを削除する
- 「後で直せる」「軽微」と判断しても必ずメモする。起票の要否はチェックリスト時に判断する

### 作業履歴MD（save-summary）の記載内容

| 含めるべき | 含めない |
| --- | --- |
| なぜその判断をしたか（背景・ビジネス制約） | ユーザーのチャットメッセージ（逐語） |
| 複数案があった場合の選択理由・トレードオフ | 試行錯誤の過程（エラーログ詳細） |
| 実装内容（変更ファイル一覧） | 問答の往復 |

---

## エージェント一覧

| エージェント | ファイル | 責務 |
|-------------|----------|------|
| SM Core | `.claude/skills/virtual-scrum-team/agents/sm-core/CLAUDE.md` | 議事録分析・スクラムイベント評価 |
| SM Daily | `.claude/skills/virtual-scrum-team/agents/sm-daily/CLAUDE.md` | デイリースクラム進行（対話式） |
| TDD Coach | `.claude/skills/virtual-scrum-team/agents/tdd-coach/CLAUDE.md` | TDD ガードレール付き支援 |
| Dependency Guardian | `.claude/skills/virtual-scrum-team/agents/dependency-guardian/CLAUDE.md` | レイヤー依存関係の検証 |

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `/scrum:run-daily` | Daily Scrum を開始 |
| `/pbi:check-story` | Story フォーマット（Gherkin）チェック |
| `/pbi:check-requirement` | Requirement フォーマットチェック |
| `/pbi:check-needs` | Needs フォーマットチェック |
| `/pbi:check-request` | Request フォーマットチェック |
| `/pbi:check-bug` | Bug フォーマットチェック |
| `/pbi:check-tech` | Tech フォーマットチェック |
| `/pbi:invoke-story-ticket-helper` | 議事録から IssueType チケット候補を抽出・仮草稿 |
| `/arch:init-dep` | 依存性ルール初期化 |
| `/arch:check-dep` | 依存性ルール違反チェック |
| `/dev:coach-tdd` | TDD セッション開始 |

## MCP ツール

（個人開発用に未設定。設定確定後にここへ記載する）

## スプリント設定

現在のスプリント設定は `.claude/skills/virtual-scrum-team/config/current-sprint.md` を参照。
変更が必要な場合は同ファイルを直接編集する。
