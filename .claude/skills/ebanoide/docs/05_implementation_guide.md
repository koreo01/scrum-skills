# 実装ガイド（Claude Code 向け）

このドキュメントは、VSCode + Claude Code で ebanoide の実装を進める際の参考資料です。
プロジェクトの全体像を把握した上で、Phase 1 → Phase 4 の順に実装してください。

---

## 全体像

```
[Google Meets が議事録を Google Drive に自動保存]
       ↓ (cron で毎日 19:00 起動)
[pipeline.py]
  ├─ Google Drive から当日分の議事録(.docx)を取得
  ├─ extract_transcript.py で発言を抽出 (JSON化)
  ├─ ルールベース除外フィルタを適用
  ├─ Detector で7パターンを検出 (Claude Haiku 4.5)
  ├─ Responder で2層出力を生成 (Claude Opus 4.7)
  ├─ Guard で品質検証 (Claude Haiku 4.5)
  ├─ Aggregator で日次サマリを生成 (Claude Opus 4.7)
  └─ slack_notify.py で SM の DM に配信
```

---

## Phase 1: ローカル環境セットアップ＆ドライラン

### 1.1 リポジトリの準備

```bash
# Mac/Linux の場合
cd .claude/skills/ebanoide

# Python 仮想環境
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 1.2 環境変数の設定

`.env` ファイルを作成（gitignoreされる前提）：

```bash
ANTHROPIC_API_KEY=sk-ant-xxxxx
SLACK_BOT_TOKEN=xoxb-xxxxx  # Phase 3で必要
```

### 1.3 設定ファイル

```bash
cp config/config.example.yaml config/config.yaml
# config.yaml を編集して以下を設定
# - notification.recipient_user_id (あなたのSlack User ID)
# - transcript_source.local.path (議事録ローカルパス)
```

### 1.4 議事録抽出のドライラン

```bash
# サンプル議事録を tests/sample_transcripts/ に配置
python scripts/extract_transcript.py \
    --input tests/sample_transcripts/sample.docx \
    --output /tmp/extracted.json \
    --pretty

# 出力を確認
cat /tmp/extracted.json | jq '.meta'
cat /tmp/extracted.json | jq '.utterances[0:3]'
```

**期待される出力**：
- `meta.title`, `meta.date`, `meta.participants` が正しく抽出されている
- `utterances` 配列に `speaker`, `timestamp`, `text` が含まれる発言が並んでいる

### 1.5 単一議事録でパイプライン実行（DRY RUN）

```bash
python scripts/pipeline.py \
    --config config/config.yaml \
    --transcript tests/sample_transcripts/sample.docx \
    --dry-run
```

**確認ポイント**：
- ログに「検出: N件」が表示される
- Slack 送信されず、コンソールにサマリが出力される
- `data/analysis_history/{date}.json` に結果が保存される

---

## Phase 2: Detector / Responder / Guard / Aggregator のチューニング

### 2.1 プロンプトファイルの活用方法

`prompts/01_detector.md` などのファイルは、Markdown 形式で書かれていますが、
パイプラインは ` ``` ` で囲まれた部分のみを System Prompt として抽出します。

プロンプトを修正したい場合：

```bash
# 1. プロンプトファイルを編集
code prompts/01_detector.md

# 2. ドライラン
python scripts/pipeline.py --dry-run --transcript tests/sample_transcripts/sample.docx

# 3. 出力を確認して再調整
```

### 2.2 Few-shot 例の追加

実運用していくと、誤検出 or 検出漏れが見つかります。その時：

```bash
# 該当パターンのFew-shot例ファイルを開く
code fewshots/V-1_examples.md

# 新しい例を追加（既存例と同じJSON構造で）
# 重要: 実議事録の発言を匿名化せずそのまま使う
#       (パイプライン内でしか使われず、Slack DMには元発言が含まれるため)

# パイプライン再実行で効果検証
python scripts/pipeline.py --dry-run --transcript ...
```

### 2.3 検出精度の評価

`data/analysis_history/` 配下のJSONを使って、検出結果を週次でレビュー：

```python
# 簡易レビュースクリプト例
import json
from pathlib import Path

history = sorted(Path("data/analysis_history").glob("*.json"))
for path in history[-7:]:  # 過去1週間
    data = json.load(open(path))
    for r in data["responses"]:
        print(f"{path.stem} | {r['pattern_id']} | {r['speaker']} | {r['trigger_summary']}")
```

レビュー観点：
- 「誤検出」（指摘対象でないのに検出された）→ Few-shot に**健全例**を追加
- 「検出漏れ」（指摘対象なのに検出されなかった）→ Few-shot に**指摘対象例**を追加
- 「Tier 設定がおかしい」→ `config.yaml` の `enabled_patterns` を調整

---

## Phase 3: Slack DM 配信の有効化

### 3.1 Slack App の作成

1. https://api.slack.com/apps → "Create New App" → "From scratch"
2. App 名: 例「ebanoide」、Workspace: あなたの自社のWS
3. **OAuth & Permissions** で以下のスコープを追加:
   - `chat:write` (DM送信)
   - `im:write` (DMチャンネルを開く)
4. **Install to Workspace** → 同意して Bot User OAuth Token を取得
5. `.env` の `SLACK_BOT_TOKEN` にセット

### 3.2 あなたの Slack User ID を取得

Slack で自分のプロフィールを開く → "..." → "メンバーIDをコピー" (U で始まる文字列)
これを `config.yaml` の `notification.recipient_user_id` に設定。

### 3.3 テスト送信

```bash
python scripts/slack_notify.py \
    --config config/config.yaml \
    --message "🔍 ebanoide テスト送信"
```

Slack DMで上記メッセージが届けば成功。

### 3.4 pipeline.py での本番送信を有効化

`scripts/pipeline.py` を編集：

```python
# 冒頭のコメントアウトを外す
from slack_notify import send_dm
```

さらにmain関数末尾を：

```python
# Slack 配信
if args.dry_run or config["safety"]["dry_run"]:
    logger.info("=== DRY RUN: 以下を送信予定 ===")
    print(summary)
else:
    send_dm(config, summary)  # ← この行を有効化
    logger.info("Slack配信完了")
```

---

## Phase 4: Google Drive 連携と自動化

### 4.1 Google Drive から議事録を取得

`scripts/gdrive_fetch.py` を作成して、Meet Recordings フォルダから当日分の .docx を取得。

実装ポイント：
- Google Service Account を作成（または OAuth 認証）
- "Meet Recordings" フォルダ ID を `config.yaml` に設定
- 当日付の .docx だけをダウンロード
- 一時ディレクトリに保存して pipeline.py に渡す

### 4.2 スケジューリング選択肢

| 方法 | 難易度 | コスト | 推奨度 |
|------|------|------|------|
| ローカルMacのcron | 低 | 0 | ★★ (PCが起動してる必要あり) |
| GitHub Actions (schedule) | 中 | 0 | ★★★★ (推奨) |
| Cloud Run + Cloud Scheduler | 高 | 月数百円 | ★★★ (本格運用) |
| AWS Lambda + EventBridge | 高 | 月数百円 | ★★★ |

**GitHub Actions の例** (`.github/workflows/daily.yml`):

```yaml
name: ebanoide Daily Run

on:
  schedule:
    - cron: "0 10 * * 1-5"  # 平日19:00 JST (UTC 10:00)
  workflow_dispatch:  # 手動実行も可能

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -r requirements.txt
      - run: python scripts/pipeline.py
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
          GDRIVE_SERVICE_ACCOUNT: ${{ secrets.GDRIVE_SERVICE_ACCOUNT }}
```

---

## トラブルシューティング

### 議事録抽出で空配列が返る

→ python-docx が認識する構造に依存。`extract_transcript.py` の正規表現を実際の議事録形式に合わせて調整してください。Google Meets の文字起こしフォーマットは変わる可能性があります。

### Detector が何も検出しない

→ プロンプトに渡している `{transcript_text}` のフォーマットを確認。`[timestamp] speaker: text` の形式になっていることを確認。

### Guard で常に NG が出る

→ Responder の出力が JSON として正しくパースできているか確認。LLMの出力に余計な前置きやMarkdownコードフェンスが含まれている場合があります。

### Slack DM が届かない

→ Bot がワークスペースにインストールされているか、`SLACK_BOT_TOKEN` の権限スコープ (`chat:write`, `im:write`) が正しいか確認。

---

## 拡張アイデア（運用が安定してから）

1. **過去議事録の遡及分析** ── 過去1ヶ月の議事録を一括分析して傾向を可視化
2. **SM自己分析モード** ── あなた自身（メンバーAさん）の発言を別途トラッキング
3. **JSONレポートのダッシュボード化** ── Streamlit などで週次/月次傾向を可視化
4. **逆Few-shot 学習** ── 「指摘されたが対応した」事例をデータ蓄積し、改善効果を測定
5. **複数SM対応** ── チーム複数のSMがそれぞれ自分の通知を受け取れる設定

---

## 開発フロー (Claude Code でやる場合)

VSCode で Claude Code を開いて、以下のような指示で進めることを想定：

```
@claude
prompts/02_responder.md と fewshots/V-1_examples.md を読んだ上で、
新しい V-1 の Few-shot 例を追加してください。
内容は以下の発言を題材にします:
[実際の議事録から抜粋した発言]
判定: 指摘対象例 / 健全例 のどちらか
```

```
@claude
pipeline.py の Responder 処理を、Anthropic SDK の messages.create に
Prompt Caching を使うように改修してください。System Prompt は
変わらない部分なのでキャッシュ対象です。
```

---

## 最後に

このシステムの目的は「**メンバーの権威依存的思考を破る**」ことです。
ebanoide からの出力をそのままメンバーに転送すると、その目的が達成できません。
ebanoide の指摘を読んだあなた（SM）が、自分の言葉と判断で介入することが、
このシステムの設計思想の核です。

実装中も、この設計思想を念頭に置いてプロンプトや出力フォーマットを
チューニングしてください。
