# scrum-skills

スクラム開発を支援する Claude Code スキル集。Virtual Scrum Team エージェント・議事録分析・PBI フォーマットチェック・アーキテクチャ依存性管理などを提供する。

## クイックスタート

```bash
# プロジェクトルートで Claude Code を起動するとスキルが自動ロードされる
cd /path/to/your/project
claude
```

チケット管理は GitHub Issues（`gh` CLI）を利用する。詳細は [CLAUDE.md](CLAUDE.md) を参照。

---

## エージェント一覧

### 自動選択エージェント（`.claude/agents/`）

発話内容に応じて Claude Code が自動的に選択する。

| エージェント | 起動条件 | 責務 |
| --- | --- | --- |
| SM Transcript Analyzer | 「議事録を分析して」「この会議を評価して」 | 議事録分析・チーム成熟度・改善機会の評価 |
| SM Event Coach | 「スクラムの問題点を教えて」「SMとして何をすべきか」 | SMコーチング・信頼度スコア付き介入設計 |
| SM Daily Facilitator | 「デイリー始めよう」「朝会やろう」`/scrum:run-daily` | 対話式 Daily Scrum の進行 |

### 手動起動エージェント（`.claude/skills/`）

| エージェント | 起動方法 | 責務 |
| --- | --- | --- |
| TDD Coach | `/dev:coach-tdd` | TDD ガードレール付き実装支援 |
| Dependency Guardian | `/arch:check-dep` | レイヤー依存関係ルールの違反検出 |

---

## コマンド一覧

### PBI チェック

| コマンド | 対象 | 説明 |
| --- | --- | --- |
| `/pbi:check-story` | Story | Gherkin 形式・ユーザー視点の振る舞い検証 |
| `/pbi:check-requirement` | Requirement | Why→What 変換・達成条件の検証 |
| `/pbi:check-needs` | Needs | ニーズ定義のフォーマット検証 |
| `/pbi:check-request` | Request | リクエスト定義のフォーマット検証 |
| `/pbi:check-bug` | Bug | バグ報告のフォーマット検証 |
| `/pbi:check-tech` | Tech | 技術的改善のフォーマット検証 |
| `/pbi:check-task` | Task | Task チケットのフォーマット検証 |
| `/pbi:check-subtask` | SubTask | SubTask チケットのフォーマット検証 |
| `/pbi:check-backbone` | Backbone | Backbone チケットのフォーマット検証 |
| `/pbi:check-narrative-flow` | Narrative Flow | Narrative Flow チケットのフォーマット検証 |
| `/pbi:check-status` | — | チケット Status 整合性チェック |
| `/pbi:slice-story` | Story | Story の縦スライス分割支援 |

### PBI テンプレート

| コマンド | 対象 | 説明 |
| --- | --- | --- |
| `/pbi:template-story` | Story | Story チケット雛形出力 |
| `/pbi:template-requirement` | Requirement | Requirement チケット雛形出力 |
| `/pbi:template-needs` | Needs | Needs チケット雛形出力 |
| `/pbi:template-bug` | Bug | Bug チケット雛形出力 |
| `/pbi:template-task` | Task | Task チケット雛形出力 |

### スクラムイベント

| コマンド | 説明 |
| --- | --- |
| `/scrum:run-daily` | Daily Scrum を対話形式で進行 |

### アーキテクチャ管理

| コマンド | 説明 |
| --- | --- |
| `/arch:init-dep` | プロジェクトのレイヤー依存性ルールを初期化 |
| `/arch:check-dep` | 依存性ルール違反を検出・レポート |

### 開発支援

| コマンド | 説明 |
| --- | --- |
| `/dev:coach-tdd` | TDD セッションを開始（Go 向け） |
| `/dev:start-session` | 開発セッション開始チェック |
| `/dev:end-session` | 開発セッション終了チェックリスト |

---

## ディレクトリ構成

```text
scrum-skills/
├── CLAUDE.md                  # Claude Code 固有ガイド
├── AGENTS.md                  # AI エージェント共通規約
├── README.md                  # このファイル
├── docs/
│   └── scrum-reference/       # スクラム参照ドキュメント
│       └── dod-and-undone.md  # DoD・Undone 処理ガイド
├── miro-usm/                  # Miro連携スクリプト（Optional Integration。下記ポリシー参照）
│   └── deploy_usm.py
└── .claude/
    ├── settings.json          # プロジェクト設定・権限
    ├── settings.local.json    # ローカル権限
    ├── agents/                # 自動選択エージェント定義
    │   ├── sm-transcript-analyzer.md
    │   ├── sm-event-coach.md
    │   └── sm-daily-facilitator.md
    ├── commands/              # スラッシュコマンド定義
    │   ├── pbi/
    │   ├── arch/
    │   ├── scrum/
    │   └── dev/
    └── skills/
        ├── virtual-scrum-team/
        │   ├── SKILL.md       # スキルトリガー条件
        │   ├── agents/        # エージェントプロンプト
        │   ├── config/        # スプリント設定
        │   ├── docs/          # 議事録処理フロー等
        │   └── templates/     # 出力テンプレート
        └── ebanoide/          # 某著名スクラムトレーナー CSM 哲学スキル
```

---

## External Tools / Services Policy

本リポジトリは、Git、MCP、Connector、AI Provider、通知サービス等の外部ツールとの連携をサポートする。

利用可能な外部サービスは企業・Projectによって異なるため、本リポジトリに含まれる Microsoft Teams・Google Drive・GitHub / Git hosting・Anthropic・Slack・Miro 等への言及やIntegration実装は、いずれも「利用例」または「選択可能なIntegration」であり、その利用を必須とするものではない。

実際に使用するサービスは、利用企業またはProjectが利用を承認したものに限定すること。外部サービスの認証情報・接続先・組織固有設定はrepositoryに保存せず、利用環境側（環境変数・Secret管理等）で設定すること。

SkillまたはAgentが外部Toolを必要とする場合、既に利用環境で承認・設定されているToolを優先して使用する。承認されたToolが利用できない場合、別の外部サービスへ自動的に切り替えたり新規接続を作成したりせず、ローカルファイルまたはユーザーから提供されたデータを利用するか、必要な設定をユーザーへ確認する。

本リポジトリが外部Toolへの接続機能を持たないことを保証するものではない。むしろ、Scrum・開発活動を支援するため外部ToolとのIntegrationを意図的にサポートしている。セキュリティ上保証する設計原則は、「外部Toolを使用する場合、その選択と接続設定は利用企業/Projectの承認・管理下に置く」ことである。

---

## Git / Remote Repository Policy

本リポジトリのGit関連Skill/Commandは、Git hosting serviceを特定製品に固定しない（Provider Neutral）。GitHub・GitHub Enterprise・GitLab・Azure DevOps・Bitbucket・Intranet上のGit serverなど、企業/Projectが承認したGit Remoteであれば、その所在（社内/社外）を問わず同等の選択肢として扱う（例: Intranet上のGitLab、AWS Private Subnet内のオンプレ型Git hosting、InternetのPrivate GitHub Repository等）。

判断基準は「Remoteの所在（社内/社外）」ではなく「企業/Projectが承認・設定したRemoteであるか否か」である。SkillまたはAgentは、未承認のGit hosting serviceへのRepository作成、利用者の指示によらないRemote URLの変更、未承認Remoteの追加を行わない。

Git Remote URL（`git remote -v`で確認できる接続先）は利用環境ごとに異なる環境依存情報であり、本リポジトリのドキュメント・設定はRemote URLを固定値として保持しない。

### Git標準操作とGitHub固有操作の区分

| 区分 | 操作例 | 性質 |
| --- | --- | --- |
| Git標準操作 | `git status` / `diff` / `commit` / `fetch` / `pull` / `push` / `branch` 等 | Git hosting serviceに依存しない基本操作 |
| GitHub固有操作 | `gh issue` / `gh pr` / `gh run` / `gh api` 等（`gh` CLI経由） | GitHub Issuesをチケット管理として利用する場合にのみ必要（詳細は [CLAUDE.md](CLAUDE.md) 参照） |

GitHub以外のGit hosting serviceを利用するProjectでは、GitHub固有操作（`gh` CLI）は不要である。そのため `.claude/settings.json`（チーム共有設定）のallowリストにはGitHub固有操作を含めない。GitHub Issuesでのチケット管理を採用するProjectは、各自の `.claude/settings.local.json`（個人環境設定・gitignore対象）側で `gh issue` / `gh pr` 等を有効化する。

### push_policy（確認要否）の設計方針

- **チーム共有設定（`.claude/settings.json`）**: `git push`・`gh pr create`・`gh issue close` 等、Remoteやチケット管理システムへの書き込みを伴う操作はallowリストに含めない。**確認要求がデフォルト（Fail-Closed）**。本Skill一式を他の企業/Projectへ流用した場合も、まず確認要求の状態からスタートする。
- **個人環境設定（`.claude/settings.local.json`）**: 自分の環境での自律的な開発ワークフローを望む場合、各自の裁量でallowリストに追加し自動化してよい。
- CLAUDE.mdの「自律実行の原則」（Claudeが会話内で重ねて承認を求めない）自体はこの方針と独立している。「permission設定で許可された操作について会話内で確認を求めない」という層の話であり、実行可否の最終ゲートはpermission設定側にある。

### Git認証情報の非保存

Git認証情報（Personal Access Token・Deploy Token・SSH鍵等）は、[AGENTS.mdの外部ツール利用の共通原則](AGENTS.md#外部ツール利用の共通原則)（Secret非保存）に従い、repositoryへ保存せず利用環境側（環境変数・Credential Manager・SSH Agent等）で管理する。

---

## 参照ドキュメント

| ドキュメント | 内容 |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | Claude Code 固有の設定・MCP ツール・コマンド詳細 |
| [AGENTS.md](AGENTS.md) | AI エージェント共通のコーディング規約・禁止事項 |
| [docs/scrum-reference/dod-and-undone.md](docs/scrum-reference/dod-and-undone.md) | DoD・Undone 処理ガイド |
| [docs/external-communication-audit.md](docs/external-communication-audit.md) | 外部通信静的検証レポート（Fail-Closed検討・外部通信箇所一覧） |
| [.claude/skills/virtual-scrum-team/docs/folder-structure.md](.claude/skills/virtual-scrum-team/docs/folder-structure.md) | 議事録処理パイプライン |
