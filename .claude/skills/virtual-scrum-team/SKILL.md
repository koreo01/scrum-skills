# Virtual Scrum Team Skill

仮想スクラムチームを構成するマルチエージェントシステムです。

## トリガー条件

以下のキーワードやコンテキストで起動します：

- 「仮想チーム」「バーチャルチーム」
- 「エージェントチーム」「AIチーム」
- 「SM Agent」「PO Agent」「Dev Agent」
- 「Daily Scrum」「デイリー」
- 各エージェント名を直接指定した場合

---

## 🎤 バーチャルチーム Daily Scrum（音声対話式）

1人のエンジニア + AI Agentsによるバーチャルチーム向けのDaily Scrumフローです。

### 使い方

```bash
# Claude Codeを起動
claude

# 音声入力を有効化（オプション）
/voice

# Daily Scrumを開始
/daily ユーザー認証機能のMVPリリース
```

### フロー

```
┌─────────────────────────────────────────────────────────────┐
│ /daily コマンドで開始                                        │
│         ↓                                                   │
│ SM Daily Agent が対話形式で質問                              │
│   1. スプリントゴール確認                                    │
│   2. 昨日やったこと（深掘りあり）                             │
│   3. 今日やること（深掘りあり）                               │
│   4. 障害・問題（検出時は対応策提案）                         │
│   5. 気づき・メモ                                           │
│         ↓                                                   │
│ サマリー確認 → レポート保存                                  │
│   → analysis/daily-logs/YYYY-MM-DD.md                       │
└─────────────────────────────────────────────────────────────┘
```

### 出力先

```
analysis/daily-logs/
├── 2026-03-27.md
├── 2026-03-28.md
└── ...
```

---

## 📁 物理チーム議事録分析フロー

物理的なチーム（Google Meets等）の議事録を分析するフローです。

### 前提条件
- `brew install pandoc` でpandocをインストール済み

### ワークフロー

```
1. Google Meets終了 → Meet Recordingsに自動保存
         ↓
2. Google Drive Webで議事録を選択 → ダウンロード(zip)
         ↓
3. zipを ~/Downloads/meet-transcripts/ に展開
         ↓
4. スクリプト実行:
   ./.claude/skills/virtual-scrum-team/scripts/import-transcripts.sh
         ↓
5. Claude Codeで分析:
   @analysis/transcripts/cleaned/daily/2026-03-26/daily-scrum.txt を分析してください
```

### 初期セットアップ

```bash
# フォルダ構造を初期化
./.claude/skills/virtual-scrum-team/scripts/init-folders.sh

# スクリプトに実行権限を付与
chmod +x ./.claude/skills/virtual-scrum-team/scripts/*.sh
```

### フォルダ構成

```
analysis/transcripts/
├── raw/           # Google Meetsからのdocx（未処理）
├── converted/     # docx → txt変換済み
└── cleaned/       # フィラー削除済み（分析対象）
    ├── daily/     # 日ごと: daily/2026-03-26/
    ├── weekly/    # 週ごと: weekly/2026-W13/
    └── events/    # イベント別: events/retro/, events/review/
```

詳細: [docs/folder-structure.md](docs/folder-structure.md)

---

## 利用可能なエージェント

### SM Agents

| Agent | 状態 | 説明 |
|-------|------|------|
| SM Daily | ✅ Ready | 音声対話式Daily Scrum進行（バーチャルチーム向け） |
| SM Core | ✅ Ready | 議事録分析（物理チーム向け） |

### コアエージェント

| Agent | 状態 | 説明 |
|-------|------|------|
| PO | 🔜 Planned | プロダクトオーナー |

### 開発チームエージェント

| Agent | 状態 | 説明 |
|-------|------|------|
| TDD Coach | ✅ Ready | ガードレール付きTDD支援（Unit Test専門） |
| Dependency Guardian | ✅ Ready | 依存関係ルール管理・違反チェック |
| Architect | 📋 Planned | 設計相談・ADR管理（Design Advisor） |
| Full-Stack | 📋 Planned | フルスタック開発 |
| E2E Test | 📋 Planned | GUIを使ったE2Eテスト（後日設計） |
| UI/UX | 📋 Planned | デザイナー |

---

## スラッシュコマンド

| コマンド | 説明 |
|----------|------|
| `/daily [スプリントゴール]` | Daily Scrumを開始（音声対話式） |
| `/tdd [実装対象]` | TDDセッションを開始（Red-Green-Refactor） |
| `/dep-check [対象パス]` | 依存関係ルール違反をチェック |
| `/dep-init [プロジェクトタイプ]` | 依存関係ルールファイルを初期化 |

---

## 🧪 TDD Coach（テスト駆動開発支援）

ガードレール付きでTDDのRed-Green-Refactorサイクルを守らせるAgentです。

### 使い方

```bash
# TDDセッションを開始
/tdd Employeeクラスの給与計算
```

### TDDサイクル

```
1. 失敗するテストを書く（Red）
2. コードを動くようにする（Green）
3. 重複をなくす、キレイにする（Refactor）
```

### ガードレール機能

| 違反 | 対応 |
|------|------|
| テストなし実装 | 🚫 停止、テスト作成に戻す |
| スケルトンなし | 🚫 停止、設計フェーズに戻す |
| 大きすぎる変更 | 🚫 停止、分割を要求 |
| フェーズ飛ばし | ⚠️ 警告、確認を促す |
| 複数検証テスト | ⚠️ 警告、分割を提案 |

### 対象

- **Unit Test専門**（Model, Service, Use Case等）
- E2E/GUIテストは別Agent（後日設計）

### Daily Scrumとの連携

Daily中に「〜を実装する」という発言があれば、TDD Coachがセッション開始を提案します。

---

## 🛡️ Dependency Guardian（依存関係管理）

Lattixのような依存関係管理をClaude Code上で実現します。

### 初期セットアップ

```bash
# 依存関係ルールファイルを初期化
/dep-init rails
```

作成されるファイル:
```
.architecture/
├── dependency-rules.yml    # 依存関係ルール
└── layer-diagram.mermaid   # レイヤー構成図
```

### 依存関係チェック

```bash
# プロジェクト全体をチェック
/dep-check

# 特定ディレクトリをチェック
/dep-check app/services/
```

### ルールの種類

| ルール | 説明 |
|--------|------|
| レイヤー方向 | Presentation → Application → Domain の方向のみ許可 |
| 循環参照禁止 | A → B → A のような循環を検出 |
| BlackList | 明示的に禁止する依存（Controller → Repository等） |
| WhiteList | 例外的に許可する依存 |

### Daily Scrumとの連携

Daily中に「新しいモジュールを追加した」などの発言があれば、SM Daily Agentが依存関係チェックを提案します。

---

## エージェント詳細

- [SM Daily Agent](agents/sm-daily/CLAUDE.md) - バーチャルチーム向け
- [SM Core Agent](agents/sm-core/CLAUDE.md) - 物理チーム議事録分析
- [TDD Coach Agent](agents/tdd-coach/CLAUDE.md) - ガードレール付きTDD支援
- [Dependency Guardian](agents/dependency-guardian/CLAUDE.md) - 依存関係管理
- [フォルダ構成](docs/folder-structure.md)

---

## 設定ファイル

- [現在のスプリント設定](config/current-sprint.md) - スプリントゴール等を設定

---

## グローバルスキルとの連携

本スキルは以下のグローバルスキルと連携可能です：

- `scrum-mentor`: 汎用的なスクラム支援（本スキルはこれを拡張）
- `transcript-analyzer`: 議事録の発言分析（前処理として使用可能）
- `transcript-cleaner`: フィラー削除（本スキル内にも同等機能あり）
