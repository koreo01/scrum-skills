# 外部通信静的検証レポート

Issue #3（Approved Tool Policy未整備）配下の最終検証Task（#11）として、repository全体を対象に外部通信箇所を静的検証した結果をまとめる。

検証日: 2026-09-30

## 検証範囲・方法

- repository全体（追跡ファイル104件、`.claude/status`・`.claude/summaries`・`.claude/projects`はgitignore対象のため除外）を対象に、外部通信関連キーワード（`http`/`https`/`webhook`/`mcp`/`anthropic`/`openai`/`google`/`slack`/`teams`/`miro`/`github`/`gh`/`curl`/`wget`/`requests`/`fetch`/`git push`等）で全文検索した
- ヒットしたファイルのうち実行コード（`.py`/`.sh`/`.yml`）を優先して精査し、実際に外部通信ライブラリ（`requests`/`slack_sdk`/`anthropic`）を import しているファイル・実行トリガー条件を特定した
- Secret/組織固有情報（API Key・Token・Webhook URL・Organization ID・Board ID等）の実値commitがないことを、`.env`系ファイルの追跡状況・トークンパターン（`sk-`/`xox`/`ghp_`/`AKIA`等）で確認した

## Fail-Closed初期値の検討結果

| 対象 | 現状 | 検討結果 |
| --- | --- | --- |
| Notification Provider（ebanoide） | `config.example.yaml`の`notification.provider`デフォルト値は`"disabled"` | 既にFail-Closed（Task #6で対応済み）。変更不要 |
| AI Provider（ebanoide `pipeline.py`のAnthropic API呼び出し） | `--offline`/`--dry-run`未指定時はデフォルトで呼び出しが発生する | 議事録分析はこのSkillの主要機能のため、デフォルト無効化は既存利用者への破壊的変更になる。値変更は見送り、その旨を`pipeline.py`の該当箇所にコメントとして記録した（[deploy_usm.py](../miro-usm/deploy_usm.py)と同様の考え方） |
| Connector（Google Drive MCP） | ユーザーがGoogle Docs URLを渡した場合のみ発動し、承認済みConnectorが前提（Task #8対応済み） | 既にFail-Closed（オプトイン設計）。変更不要 |
| Optional Integration（Miro） | `MIRO_ACCESS_TOKEN`/`MIRO_BOARD_ID`環境変数が未設定の場合は起動時に例外で停止する | 既にFail-Closed（未設定なら実行不可）。変更不要 |

## Secret・組織固有情報の実値commit確認

- `.env`系ファイルはgit追跡対象に存在しない
- APIキー/トークンのパターン（`sk-`, `xox[baprs]-`, `ghp_`, `AKIA`, PEM秘密鍵等）を全文検索したが該当なし
- `MIRO_BOARD_ID`/`MIRO_ACCESS_TOKEN`等の環境変数に実値が代入されているコードは存在しない（すべて`os.environ[...]`による参照のみ）

実値commitは確認されなかった。

## 外部通信箇所の分類一覧

分類基準:

- **A: Documentation only** — キーワードが文章中で言及されているのみで、実行コードを伴わない
- **B: Optional Integration** — 明示的な環境変数設定・Connector承認がある場合のみ動作する
- **C: External Operation** — リポジトリの開発ワークフロー運用上、意図的に発生する操作（GitHubFlow・CI）
- **D: Unexpected External Communication** — 意図しない・無条件の外部通信

| File | Purpose | External Service | Data potentially transmitted | Trigger condition | Requires explicit configuration | Default enabled/disabled | Approved-tool policy compliance | 分類 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `.claude/skills/ebanoide/scripts/pipeline.py` | 議事録のパターン検出・応答生成 | Anthropic API | 議事録テキスト（発言内容） | `pipeline.py`実行時（`--offline`/`--dry-run`未指定） | `ANTHROPIC_API_KEY`環境変数必須 | Enabled（`--offline`で無効化可） | Compliant | B |
| `.claude/skills/ebanoide/scripts/slack_notify.py` | 日次サマリのSlack DM配信 | Slack API | サマリテキスト | `send_dm()`呼び出し時（現状`pipeline.py`からは未接続・実装時に有効化予定） | `SLACK_BOT_TOKEN`環境変数＋`config.notification.recipient_user_id`必須 | Disabled（未接続） | Compliant | B |
| `.claude/skills/ebanoide/config/config.example.yaml` | Notification Provider設定テンプレート | 設定次第（Slack/Teams等） | 設定次第 | `provider`が`"disabled"`以外の場合 | `provider`明示指定必須 | Disabled（デフォルト） | Compliant | B |
| `miro-usm/deploy_usm.py` | USMをMiroボードに自動展開 | Miro API | USM構造データ（ストーリー名・ステータス等） | スクリプト実行時 | `MIRO_ACCESS_TOKEN`・`MIRO_BOARD_ID`環境変数必須（未設定ならKeyErrorで起動不可） | Disabled（未設定なら実行不可） | Compliant | B |
| `.claude/agents/sm-event-coach.md` | 議事録の自動取得 | Google Drive MCP | Google Docs文書内容（議事録） | ユーザーがGoogle Docs URLを渡した場合のみ | 利用環境でGoogle Drive MCP Connectorが承認・設定済みであることが前提 | Disabled（URL入力時のみ） | Compliant | B |
| `.claude/agents/sm-transcript-analyzer.md` | 議事録の自動取得 | Google Drive MCP | 同上 | 同上 | 同上 | Disabled | Compliant | B |
| `.claude/hooks/pre-push-quality-gate.sh` | `git push`前の品質ゲート | GitHub（push先リモート） | コミット内容（コード） | `git push`コマンド実行時 | リポジトリのgit remote設定（利用者側） | Enabled（GitHubFlow運用の一部） | Compliant | C |
| `.claude/commands/dev/end-session.md` | セッション終了時のPR作成・マージ・Issue更新 | GitHub（`gh` CLI） | コミット内容・チケット情報 | `/dev:end-session`実行時 | `gh` CLI認証（利用者側） | Enabled（チケット管理運用の一部） | Compliant | C |
| `.claude/commands/dev/start-session.md` | セッション開始時のPR状態確認 | GitHub（`gh` CLI） | チケット情報 | `/dev:start-session`実行時 | `gh` CLI認証（利用者側） | Enabled | Compliant | C |
| `.github/workflows/quality-gate.yml` | CI品質ゲート | GitHub Actions（`actions/checkout@v4`） | リポジトリコード | push/PR時 | GitHub Actions標準機能 | Enabled（CI標準動作） | Compliant | C |
| 上記以外（`README.md`・`CLAUDE.md`・`AGENTS.md`・`.claude/commands/pbi/*.md`・`.claude/skills/ebanoide/docs/*.md`等、約60ファイル） | ポリシー説明・コマンド定義・用語言及 | — | — | — | — | — | 実行コードを含まないため対象外 | A |

**D（Unexpected External Communication）: 0件。**

cron/schedule等による自動定期実行トリガーはrepository内に存在せず、外部通信ライブラリ（`requests`/`slack_sdk`/`anthropic`）のimportは上記B分類の3ファイルに限定されることを確認した。

## 結論

- Fail-Closedの観点では、Notification/Connector/Optional Integrationは既に無効がデフォルトになっている。AI Provider（ebanoideのAnthropic API呼び出し）のみ主要機能として意図的にデフォルト有効としており、この判断根拠を`pipeline.py`にコメントで残した
- Secret・組織固有情報の実値commitは確認されなかった
- 意図しない外部通信（D分類）は0件

Issue #3配下のTask（#4〜#11）はこれで完了する。
