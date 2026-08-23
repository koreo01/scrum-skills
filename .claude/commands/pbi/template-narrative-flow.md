# PBI Template Narrative Flow

check-narrative-flow.md のチェックを通過しやすい Narrative Flow チケットの雛形を出力します。

## コマンド形式

```
/pbi:template-narrative-flow [--title "タイトル"]
```

| 引数 | 説明 |
|-----|------|
| `--title "タイトル"` | タイトルをあらかじめ埋めた状態で出力 |
| （省略） | 全フィールドが空欄の雛形を出力 |

---

## 使い方

1. このコマンドを実行すると、下記テンプレートを出力します
2. `[...]` で囲まれた部分を実際の内容に置き換えてください
3. 記載後に `/pbi:check-narrative-flow` で品質確認してください

---

## 出力テンプレート

以下のテンプレートをそのまま出力する：

```markdown
# [Narrative Flowタイトル]
<!-- Title形式: フロー/シナリオ形式 -->
<!-- 例: 「新規ユーザーが初回ログインからダッシュボード確認まで行うフロー」「注文確定から配送完了通知受信までの流れ」「管理者がユーザー権限を変更するシナリオ」 -->
<!-- NG例: 「〇〇の改善」（Backbone形式）/ 「〇〇は△△できる」（Story形式）/ 「〇〇を実装する」（Task形式） -->
[ユーザー/ペルソナ]が[開始状態]から[終了状態]まで行うフロー

【概要】
[このNarrative Flowが表すユーザーシナリオの要約]
<!-- ユーザーの行動・体験フロー全体を説明する。実装詳細（API・DB等）は書かない -->

【対象ユーザー】
[このフローを辿るユーザーの属性・文脈]
<!-- 例: 「新規登録済みの一般ユーザー（初回ログイン前）」「管理者ロールを持つユーザー」「エンタープライズプランの担当者」 -->

【フロー概要】
1. [ステップ1: ユーザーアクションを具体的に記述]
2. [ステップ2: ユーザーアクションを具体的に記述]
3. [ステップ3: ユーザーアクションを具体的に記述]
<!-- ユーザーの操作・体験として記述する。「APIを呼ぶ」「DBを更新する」等の実装詳細は書かない -->

【親Backbone】
#xxxx: [Backboneのタイトル（「〇〇の改善」「〇〇の強化」等のテーマ形式）]

【配下Story】（Status=Story Defined以降は必須）
- [ ] #xxxx: [Story1のタイトル（「〇〇は△△できる」形式）]
- [ ] #xxxx: [Story2のタイトル]
```

---

## GitHub ラベル設定ガイド

| プロパティ | 値 | 設定タイミング |
|-----------|-----|-------------|
| Type | Narrative Flow | 作成時 |
| Status | Refining | 起票時（シナリオの流れを精査中） |
| Owner | Business | 起票〜Refiningまで（必須） |

### Owner × Status の整合ルール

| Status | Owner |
|--------|-------|
| Refining | Business |
| Story Defined 以降 | Product |

### Narrative Flowに存在しないプロパティ

- **Triage ステータスなし**: Narrative Flow の Status は `Refining / Story Defined / Done` の3段階のみ
- **Workflow State なし**: Narrative Flow には Workflow State プロパティが存在しない

---

## check-narrative-flow.md チェック項目との対応

| チェック項目 | テンプレートの対応箇所 |
|------------|----------------------|
| 0-1 Status有効値 | プロパティ設定ガイド参照（Refining / Story Defined / Done） |
| 0-2 Owner設定 | プロパティ設定ガイド参照 |
| 0-3 Owner×Status整合 | Owner × Status の整合ルール参照 |
| 1 Title形式（フロー/シナリオ形式） | 1行目のタイトルとコメント |
| 2 概要/目的の存在 | `【概要】` セクション |
| 3 親Backboneリンク | `【親Backbone】` セクション |
| 4 配下Storyリンク | `【配下Story】` セクション（Story Defined以降は必須） |
| 5 フロー概要（ステップ）の記載 | `【フロー概要】` の番号付きステップ |
| 6 対象ユーザー/起点の明示 | `【対象ユーザー】` セクション |
| 7 ユーザー視点の一貫性 | `【フロー概要】` のコメント（実装詳細なし） |
| 8 Story分解可能性 | `【配下Story】` の箇条書き構造 |
| 9 Backboneとの整合性 | `【親Backbone】` と `【概要】` を同じテーマで統一 |

---

## よくある記載ミス

| ミスのパターン | 正しい書き方 |
|-------------|------------|
| Title: 「ログイン機能」 | 機能名称はNarrative Flowの形式ではない。「ユーザーが初回ログインからダッシュボード確認まで行うフロー」のようなフロー形式で記載 |
| Title: 「〇〇は△△できる」 | Story の形式。Narrative Flow は「〇〇が△△するフロー」形式で記載 |
| Title: 「〇〇の改善」「〇〇の強化」 | Backbone の形式。Narrative Flow はユーザーシナリオの流れを表す |
| Title: 「〇〇を実装する」 | Task/SubTask の形式。Narrative Flow はユーザー視点で記述する |
| フロー概要: 「APIを呼ぶ」「DBを更新する」「バックエンドが処理する」 | 実装詳細はNarrative Flowに書かない。「ユーザーが〇〇画面で△△を入力する」のようなユーザーアクションで記述 |
| 親Backboneリンクなし | `【親Backbone】` セクションに `#xxxx: タイトル` 形式で必ず記載（チェックで❌） |
| Status=Story Defined なのに配下Storyリンクなし | Story Defined 以降は配下Story（#xxxx）へのリンクが必須（チェックで❌） |
