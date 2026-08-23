# ebanoide Skill

Google Meets 議事録を日次バッチで分析し、SM（スクラムマスター）が介入すべき発話パターンを検出して Slack DM で通知するシステムです。
SM の観察・介入タイミングを機械的に補完し、スクラムガバナンスの継続的維持を支援します。

## トリガー条件

以下のキーワードやコンテキストで参照します：

- 「ebanoide」「議事録を分析して」「SM介入候補」
- 「スプリントイベントの議事録をチェックして」
- `scripts/pipeline.py` の実行時

---

## システム概要

### 設計原則

1. **権威依存の回避**: 「誰かがそう言っていた」ではなく「学問的・原理的にこう導かれる」という論理プロセスを必ず含める
2. **2層出力**: SMへの分析（強・詳細） / メンバー介入時に使える問いの型（柔・実用版）
3. **完成指摘文を出さない**: SM が自分の言葉に翻訳する 1 ステップを必ず挟む
4. **SM 職務遂行上の通常活動**: メンバーへの個別開示は不要

### パイプライン

```
[Google Meets 議事録（.docx）]
    ↓
[抽出: text + 話者付き発言]  scripts/extract_transcript.py
    ↓
[除外フィルタ]
    ├─ 個人事情・健康・休暇
    ├─ 純粋な業務連絡
    └─ 適切な質問（根拠付き）
    ↓
[Detector: 検出]              prompts/01_detector.md  (Haiku 4.5)
    ↓
[Responder: 応答生成]          prompts/02_responder.md (Opus 4.7)
    ├─ SMへの分析（強）
    └─ メンバー介入時の問いの型（柔）
    ↓
[Guard: 品質チェック]           prompts/03_guard.md     (Haiku 4.5)
    ├─ 人格攻撃チェック
    └─ 権威依存チェック
    ↓
[Aggregator: 日次サマリ生成]   prompts/04_aggregator.md (Opus 4.7)
    └─ 個別指摘 + メタ分析（傾向）
    ↓
[Slack DM 配信]               scripts/slack_notify.py
```

---

## 検出パターン v3.5

| ID | 名称 | Tier | 通知モード |
|----|------|------|-----------|
| V-1 | 過去経緯不明の放置 | S（最重要） | 即時＋サマリ |
| V-4 | 注意力依存の対症療法 | A | サマリ |
| V-3 | 判定基準なき並列提案 | A | サマリ |
| V-5 | 保留表現の連鎖 | B | サマリ |
| V-6 | 顧客要望の解像度不足 | B | サマリ |
| S-3 | 100か0の二元論 | B | サマリ |
| V-2 | 根拠なき確認質問 | C | サマリ末尾のみ |

各パターンの詳細は [docs/02_patterns_v3.5.md](docs/02_patterns_v3.5.md) を参照。

---

## ファイル構成

```
.claude/skills/ebanoide/
├── SKILL.md                        # このファイル
├── requirements.txt                # Python 依存パッケージ
├── config/
│   └── config.example.yaml        # 設定ファイルテンプレート
├── prompts/
│   ├── 01_detector.md             # 検出プロンプト（Haiku 4.5）
│   ├── 02_responder.md            # 応答生成プロンプト（Opus 4.7）
│   ├── 03_guard.md                # 品質ガードプロンプト（Haiku 4.5）
│   ├── 04_aggregator.md           # 日次サマリ生成プロンプト（Opus 4.7）
│   └── system_philosophy.md       # SM介入哲学（共通リファレンス）
├── fewshots/
│   ├── V-1_examples.md
│   ├── V-2_examples.md
│   ├── V-3_examples.md
│   ├── V-4_examples.md
│   ├── V-5_examples.md
│   ├── V-6_examples.md
│   └── S-3_examples.md
├── docs/
│   ├── 01_real_data_analysis.md   # 実データ分析結果
│   ├── 02_patterns_v3.5.md        # パターン仕様
│   ├── 03_exclusion_rules.md      # 除外フィルタ仕様
│   ├── 04_output_format.md        # 出力フォーマット仕様
│   └── 05_implementation_guide.md # 実装ガイド
└── scripts/
    ├── extract_transcript.py      # docx → 話者付き発言 JSON 抽出
    ├── pipeline.py                # メインのバッチ処理
    ├── slack_notify.py            # Slack DM 配信
    └── README.md                  # スクリプト実装ガイド
```

---

## セットアップ

### 前提条件

- Python 3.10 以上
- `ANTHROPIC_API_KEY`（Anthropic API キー）
- `SLACK_BOT_TOKEN`（Slack Bot トークン）
- `SLACK_USER_ID`（SM 本人の Slack User ID）

### インストール

```bash
cd .claude/skills/ebanoide
pip install -r requirements.txt
```

### 設定ファイルの準備

```bash
cp config/config.example.yaml config/config.yaml
# config/config.yaml を編集して API キー・Slack 設定を記入
```

---

## 使い方

### テスト実行（DRY RUN）

```bash
python .claude/skills/ebanoide/scripts/pipeline.py \
  --dry-run \
  --transcript /path/to/transcript.docx
```

### 本番運用（cron）

```bash
# 毎日19:00に実行
0 19 * * * cd /path/to/project && \
  python .claude/skills/ebanoide/scripts/pipeline.py
```

### 手動分析（Claude Code から）

議事録ファイルを指定して直接分析を依頼する場合：

```
@.claude/skills/ebanoide/prompts/01_detector.md
議事録: [議事録テキストをここに貼り付け]
```

---

## 実装フェーズ

| Phase | 内容 | 状態 |
|-------|------|------|
| Phase 1 | `extract_transcript.py` の実装（docx → 話者付き JSON） | 未実装 |
| Phase 2 | `pipeline.py` の実装（4段階パイプライン） | 未実装 |
| Phase 3 | `slack_notify.py` の実装（Slack DM 配信） | 未実装 |
| Phase 4 | スケジューリング（cron / GitHub Actions / Cloud Run） | 未実装 |

詳細は [docs/05_implementation_guide.md](docs/05_implementation_guide.md) を参照。

---

## 関連ドキュメント

- [パターン仕様 v3.5](docs/02_patterns_v3.5.md) — 7検出パターンの詳細定義
- [除外フィルタ仕様](docs/03_exclusion_rules.md) — 検出対象から除外するケース
- [出力フォーマット仕様](docs/04_output_format.md) — Slack 通知・サマリの形式
- [実装ガイド](docs/05_implementation_guide.md) — 実装手順（Claude Code 向け）
