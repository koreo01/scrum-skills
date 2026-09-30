# scrum-skills — AI コーディングガイド

> このファイルは AI コーディングエージェント（Claude Code, Cursor, Copilot 等）共通のルールです。
> ツール固有の設定: Claude Code → `CLAUDE.md`

## プロジェクト概要

スクラム開発を支援する Claude Code スキル集。以下を提供する。

| 機能 | 説明 |
|------|------|
| Virtual Scrum Team | SM・PO・Dev Team の仮想エージェントチーム |
| 議事録分析 | Google Meets 議事録の処理・発言パターン分析 |
| PBI チェック | Requirement / Story / Bug 等のフォーマット検証 |
| アーキテクチャ管理 | レイヤー依存関係ルールの初期化・違反検出 |

## コーディング規約

- **言語:** コメント・ドキュメント・コミットメッセージはすべて**日本語**で記述する
- **コミット形式:** `[BI-{親ID}/BI-{SubTaskID}] 説明` または `[BI-{ID}] 説明`（チケット番号必須・詳細は CLAUDE.md 参照）
- **図表:** フローやアーキテクチャを示す場合は Mermaid 記法を使用する
- **Markdown:** エージェント定義・コマンド定義はフロントマターを正確に記述する

## ファイル・ディレクトリ規約

```
.claude/
├── commands/         # スラッシュコマンド定義（{category}/{name}.md）
│   ├── pbi/          # PBI フォーマットチェック系
│   ├── arch/         # アーキテクチャ管理系
│   └── scrum/        # スクラムイベント系
└── skills/           # スキル定義
    └── virtual-scrum-team/
        ├── agents/   # エージェントプロンプト（{role}/CLAUDE.md）
        ├── config/   # スプリント設定
        ├── docs/     # スキル固有ドキュメント
        └── templates/ # 出力テンプレート
```

## スキル・コマンド定義のルール

- 新しいコマンドは `.claude/commands/{category}/` に配置する
- コマンドファイルには必ずトリガー条件・入力仕様・出力仕様を明記する
- エージェントプロンプトは役割・責務・ガードレールを明確に分離して記述する
- 既存スキルを変更する場合は影響範囲を確認してから変更する

## Gherkin（Story 受け入れ条件）規約

Story の受け入れ条件は**ユーザー視点の振る舞い**で記述する。

**OK（ユーザー視点）:**
- 「予約日時が更新される」
- 「確認メールが届く」

**NG（実装・設計詳細）:**
- 「PUT /reservations/{id} API が呼ばれる」（エンドポイント詳細）
- 「DB のテーブルが更新される」（インフラ詳細）

## PBI の Issue 系統

```
Issue (Why)       → Requirement (What)  → Story (What Specified)
├── Needs         → Requirement         → Story
├── Request       → Requirement         → Story
├── Bug           → Requirement         → Story
└── Tech          → Requirement         → Story
```

## 外部ツール利用の共通原則

Skill・Agent定義が外部Tool（MCP・Connector・AI Provider・通知サービス等）を利用する場合、以下の6原則に従う（詳細は [README.md](README.md) の「External Tools / Services Policy」を参照）。

1. **承認済みTool限定**: 利用企業/Projectが承認し、実行環境に設定済みのTool/Connector/MCPのみを使用する
2. **自動新規接続禁止**: 承認されたToolが利用できない場合でも、別の外部サービスへ自動的に切り替えたり新規に接続を作成したりしない
3. **データ送信禁止**: 業務データ・ソースコード・議事録等を、承認されていない外部サービスへ送信しない
4. **既存承認済みTool優先**: 複数のIntegration手段がある場合、既に利用環境で承認・設定されているToolを優先する
5. **未承認時のローカルデータ利用/ユーザー確認**: 承認済みToolが利用できない場合、ローカルファイルまたはユーザーから提供されたデータを利用するか、必要な設定をユーザーへ確認する
6. **Secret非保存**: 外部サービスの認証情報・接続先・組織固有設定はrepositoryに保存せず、利用環境側（環境変数・Secret管理等）で設定する

> Claude Code固有のツール選定（チケット管理はGitHub Issues経由・MCPサーバー不使用等）は [CLAUDE.md](CLAUDE.md) の「外部ツール利用ルール」を参照。

## 禁止事項

- エージェントプロンプト内に特定プロジェクトの機密情報をハードコードしない
- スキル定義ファイル（SKILL.md）の `trigger` セクションを無断で削除・変更しない
- 議事録データ（`analysis/transcripts/`）を Git にコミットしない（`.gitignore` で除外済み）
- `settings.json` の `deny` ルールを削除・回避しない

## 基本方針

- 不明な点は積極的に質問する
- 選択肢には推奨度（⭐5段階）と理由を提示する
- エージェント定義の変更は小さく・意図を明確にしてコミットする
