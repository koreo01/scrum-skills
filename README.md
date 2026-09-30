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
        └── ebanoide/          # 江端 CSM 哲学スキル
```

---

## External Tools / Services Policy

本リポジトリは、Git、MCP、Connector、AI Provider、通知サービス等の外部ツールとの連携をサポートする。

利用可能な外部サービスは企業・Projectによって異なるため、本リポジトリに含まれる Microsoft Teams・Google Drive・GitHub / Git hosting・Anthropic・Slack・Miro 等への言及やIntegration実装は、いずれも「利用例」または「選択可能なIntegration」であり、その利用を必須とするものではない。

実際に使用するサービスは、利用企業またはProjectが利用を承認したものに限定すること。外部サービスの認証情報・接続先・組織固有設定はrepositoryに保存せず、利用環境側（環境変数・Secret管理等）で設定すること。

SkillまたはAgentが外部Toolを必要とする場合、既に利用環境で承認・設定されているToolを優先して使用する。承認されたToolが利用できない場合、別の外部サービスへ自動的に切り替えたり新規接続を作成したりせず、ローカルファイルまたはユーザーから提供されたデータを利用するか、必要な設定をユーザーへ確認する。

本リポジトリが外部Toolへの接続機能を持たないことを保証するものではない。むしろ、Scrum・開発活動を支援するため外部ToolとのIntegrationを意図的にサポートしている。セキュリティ上保証する設計原則は、「外部Toolを使用する場合、その選択と接続設定は利用企業/Projectの承認・管理下に置く」ことである。

---

## 参照ドキュメント

| ドキュメント | 内容 |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | Claude Code 固有の設定・MCP ツール・コマンド詳細 |
| [AGENTS.md](AGENTS.md) | AI エージェント共通のコーディング規約・禁止事項 |
| [docs/scrum-reference/dod-and-undone.md](docs/scrum-reference/dod-and-undone.md) | DoD・Undone 処理ガイド |
| [docs/external-communication-audit.md](docs/external-communication-audit.md) | 外部通信静的検証レポート（Fail-Closed検討・外部通信箇所一覧） |
| [.claude/skills/virtual-scrum-team/docs/folder-structure.md](.claude/skills/virtual-scrum-team/docs/folder-structure.md) | 議事録処理パイプライン |
