# 議事録処理フォルダ構成

## 📁 ディレクトリ構造

```
.claude/skills/virtual-scrum-team/
├── SKILL.md
├── agents/
│   ├── sm-core/CLAUDE.md
│   └── ...
├── docs/
└── scripts/
    ├── import-transcripts.sh      # docx取り込み＆変換
    └── clean-fillers.sh           # フィラー削除

analysis/
├── transcripts/
│   ├── raw/                       # ① Google Meetsからのdocx（未処理）
│   │   └── 2026-03-26/
│   │       ├── daily-scrum.docx
│   │       └── sprint-review.docx
│   │
│   ├── converted/                 # ② docx → txt変換済み
│   │   └── 2026-03-26/
│   │       ├── daily-scrum.txt
│   │       └── sprint-review.txt
│   │
│   └── cleaned/                   # ③ フィラー削除済み（分析対象）
│       ├── daily/                 # 日ごと
│       │   ├── 2026-03-24/
│       │   │   └── daily-scrum.txt
│       │   ├── 2026-03-25/
│       │   │   └── daily-scrum.txt
│       │   └── 2026-03-26/
│       │       └── daily-scrum.txt
│       │
│       ├── weekly/                # 週ごと（長期傾向分析用）
│       │   ├── 2026-W12/
│       │   │   ├── daily-scrum-mon.txt
│       │   │   ├── daily-scrum-tue.txt
│       │   │   └── ...
│       │   └── 2026-W13/
│       │
│       └── events/                # イベント別（Retro, Review等）
│           ├── retro/
│           │   └── 2026-03-22-sprint5-retro.txt
│           ├── review/
│           │   └── 2026-03-22-sprint5-review.txt
│           └── planning/
│               └── 2026-03-25-sprint6-planning.txt
│
└── results/                       # 分析結果
    ├── daily/                     # 日次分析レポート
    │   └── 2026-03-26-daily-analysis.md
    ├── weekly/                    # 週次サマリー
    │   └── 2026-W13-summary.md
    └── monthly/                   # 月次傾向レポート
        └── 2026-03-trend.md
```

---

## 🔄 処理フロー

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Google Meets 終了                                            │
│     ↓                                                           │
│  2. Google Drive > Meet Recordings に自動保存（.gdoc）            │
│     ↓                                                           │
│  3. Google Drive Web で選択 → ダウンロード（.docx としてzip）      │
│     ↓                                                           │
│  4. ~/Downloads/meet-transcripts/ に展開                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  import-transcripts.sh 実行                                      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Step 1: docx → raw/ に配置（日付フォルダ自動作成）            ││
│  │ Step 2: pandoc で txt に変換 → converted/ に配置            ││
│  │ Step 3: フィラー削除 → cleaned/daily/ に配置                ││
│  │ Step 4: 週フォルダにもシンボリックリンク作成                   ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Claude Code で分析                                              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ SM Core Agent で cleaned/daily/2026-03-26/ を分析            ││
│  │ 結果を results/daily/2026-03-26-daily-analysis.md に出力     ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 ファイル命名規則

### 議事録ファイル

```
{event-type}.txt
```

| イベント | ファイル名 |
|----------|-----------|
| デイリースクラム | `daily-scrum.txt` |
| スプリントレビュー | `sprint-review.txt` |
| スプリントレトロ | `sprint-retro.txt` |
| スプリントプランニング | `sprint-planning.txt` |
| リファインメント | `refinement.txt` |
| その他 | `{topic-name}.txt` |

### 分析結果ファイル

```
{YYYY-MM-DD}-{event-type}-analysis.md
```

例: `2026-03-26-daily-scrum-analysis.md`

---

## 🗓️ 長期傾向分析のためのフォルダ構成

### 日次分析
```
cleaned/daily/2026-03-26/daily-scrum.txt
  → results/daily/2026-03-26-daily-analysis.md
```

### 週次集計
```
cleaned/weekly/2026-W13/
  ├── daily-scrum-mon.txt → ../daily/2026-03-24/daily-scrum.txt へのシンボリックリンク
  ├── daily-scrum-tue.txt → ../daily/2026-03-25/daily-scrum.txt
  └── ...
  
  → results/weekly/2026-W13-summary.md（週の傾向分析）
```

### 月次傾向
```
results/monthly/2026-03-trend.md
  └── 3月の全Daily分析結果を集約した傾向レポート
```

---

## 🔧 必要なツール

| ツール | 用途 | インストール |
|--------|------|-------------|
| pandoc | docx → txt 変換 | `brew install pandoc` |
| sed/awk | フィラー削除 | macOS標準 |

---

## 次のステップ

1. `import-transcripts.sh` - 取り込み＆変換スクリプト
2. `clean-fillers.sh` - フィラー削除スクリプト
3. SM Core Agent の入力パス設定更新
4. 週次/月次集計Agent（将来）
