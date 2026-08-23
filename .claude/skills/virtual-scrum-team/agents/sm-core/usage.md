# SM Core Agent 操作マニュアル

スクラムイベントの議事録を SM Core Agent で分析するための手順。

## セットアップ（初回のみ）

```bash
# 1. pandoc をインストール
brew install pandoc

# 2. スクリプトに実行権限を付与
chmod +x ./.claude/skills/virtual-scrum-team/scripts/*.sh

# 3. フォルダ構造を初期化
./.claude/skills/virtual-scrum-team/scripts/init-folders.sh
```

---

## 日次の分析手順

### Step 1: 議事録をダウンロード

1. Google Drive Web で会議の議事録（.docx）を選択
2. 右クリック → ダウンロード（zip ファイルとして保存される）
3. zip を展開して `~/Downloads/meet-transcripts/` に置く

### Step 2: 議事録を取り込む

**議事録の開催日付** を `YYYY-MM-DD` 形式で引数に渡して実行する。

```bash
# 例: 2026年4月6日の議事録を取り込む
./.claude/skills/virtual-scrum-team/scripts/import-transcripts.sh 2026-04-06
```

スクリプトは `~/Downloads/meet-transcripts/` 内のファイルのうち、**ファイル名に `2026_04_06` を含むものだけを処理**する（Google Meet のファイル名形式 `YYYY_MM_DD` に対応）。複数日分のファイルが混在していても、指定した日付のファイルだけが対象になる。

> **注意**: 日付を省略するとスクリプト実行日（今日）がフォルダ名になり、かつその日付でフィルタリングされる。必ず議事録の「開催日」を渡すこと。

スクリプト完了後、「次のステップ」として分析コマンドが表示される。

### Step 3: Claude Code で分析を実行

SM Core のシステムプロンプトをロードしてインタラクティブセッションを起動する。

```bash
claude --system-prompt "$(cat .claude/skills/virtual-scrum-team/agents/sm-core/CLAUDE.md)"
```

セッションが起動したら、以下をタイプして送信する（日付を実際の日付に置き換える）：

```text
@.claude/analysis/transcripts/cleaned/daily/2026-04-06/daily-scrum.txt を分析してください
```

### Step 4: 分析結果を確認

結果は以下のパスに保存される：

| イベント | 保存先 |
| --- | --- |
| Daily Scrum | `.claude/analysis/results/daily/YYYY-MM-DD-daily-scrum-analysis.md` |
| Sprint Review | `.claude/analysis/results/events/YYYY-MM-DD-sprint-review-analysis.md` |
| Sprint Retrospective | `.claude/analysis/results/events/YYYY-MM-DD-sprint-retro-analysis.md` |
| Sprint Planning | `.claude/analysis/results/events/YYYY-MM-DD-sprint-planning-analysis.md` |
| Backlog Refinement | `.claude/analysis/results/events/YYYY-MM-DD-refinement-analysis.md` |

---

## 複数日をまとめて取り込む

先週分など複数日の議事録を処理する場合は、日付ごとに繰り返す。

```bash
./.claude/skills/virtual-scrum-team/scripts/import-transcripts.sh 2026-04-07
./.claude/skills/virtual-scrum-team/scripts/import-transcripts.sh 2026-04-08
./.claude/skills/virtual-scrum-team/scripts/import-transcripts.sh 2026-04-09
```

---

## スクラムイベント別の分析依頼例

セッション内でのプロンプト例：

```text
# Daily Scrum
@.claude/analysis/transcripts/cleaned/daily/2026-04-06/daily-scrum.txt を分析してください

# Sprint Retrospective
@.claude/analysis/transcripts/cleaned/events/retro/2026-04-04-sprint6-retro.txt を分析してください

# Sprint Review
@.claude/analysis/transcripts/cleaned/events/review/2026-04-04-sprint6-review.txt を分析してください
```

---

## 関連ドキュメント

- [CLAUDE.md](CLAUDE.md) — SM Core Agent のプロンプト本体
- [test-guide.md](test-guide.md) — Agent の品質評価・プロンプト改善ガイド
- [../../docs/folder-structure.md](../../docs/folder-structure.md) — 議事録処理パイプラインの詳細
