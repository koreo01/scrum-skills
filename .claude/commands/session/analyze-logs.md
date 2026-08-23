# /session:analyze-logs — セッションログ分析パイプライン

セッションログの L1 フィルタ → L2 構造解析 → L3 個別 LLM 分析（Agent 並列） → L4 集約レポートを実行します。

## パイプライン概要

```
[ローカル JSONL ファイル群]  analysis/session-logs/
    |
[L1 フィルタ]               scripts/filter-sessions-l1.sh
    |
[L2 構造解析]               scripts/filter-sessions-l2.sh (jq)
    |
[L3 個別分析]               Session Log Analyzer Agent x N (並列)
    |   出力: analysis/results/session-logs/sessions/{product}/{user}/{date}/{uuid}.json
    |
[L4 日次サマリー]           メインコンテキストで集約（product/user/日付ごと）
    |   出力: analysis/results/session-logs/daily/{product}/{user}/{YYYY-MM-DD}.md
```

## 実行手順

### Phase 1: L1 + L2 パイプライン実行

```bash
./scripts/filter-sessions-l1.sh --format json | ./scripts/filter-sessions-l2.sh > /tmp/l2-results.jsonl
```

L2 結果を `/tmp/l2-results.jsonl` に保存する（1行1セッションの JSONL）。

### Phase 2: L3 個別分析（Agent 並列）

L2 結果を読み込み、各セッションに対して Session Log Analyzer エージェントをバックグラウンドで起動する。

**並列度の目安**: 最大 5 エージェント同時起動。それ以上の場合はバッチに分ける。

各エージェントに渡すプロンプト:

```
以下のセッションを分析してください。

## セッション情報
- ファイル: {filepath}
- 出力先: analysis/results/session-logs/sessions/{product}/{user}/{date}/{uuid}.json

## L2メタデータ
{L2 JSON をそのまま貼り付け}

## 指示
1. L2メタデータを確認し、セッション規模と特徴を把握
2. L2で検出されたトリガー（triggers）があれば、JSONL内で文脈を確認し、誤検出か正当かを判定
3. セッション JSONL の先頭50行・末尾50行を Read してコンテキストを把握
4. 必要に応じて user タイプのメッセージを追加サンプリング
5. 分析結果を出力先パスに JSON で Write（triggers フィールドにL2トリガーの確認結果を含める）
6. highlights（良い行動・優れた実践）を検出し、出力の highlights 配列に含める

エージェント定義（.claude/agents/session-log-analyzer.md）の出力フォーマットに従うこと。
```

### Phase 3: 結果確認

全エージェント完了後、個別分析の結果ファイルを確認する:

```bash
find analysis/results/session-logs/sessions/ -name "*.json" -type f | sort
```

出力パスはソースフォルダ構成をミラーリングしている: `sessions/{product}/{user}/{date}/{uuid}.json`

### Phase 3.5: L3 結果品質チェック

L4 集約の前に、個別分析 JSON の品質を検証する。以下のチェックを全ファイルに対して実行する:

```bash
# 品質チェックスクリプト（jq）
for f in $(find analysis/results/session-logs/sessions/ -name "*.json" -newer /tmp/l2-results.jsonl); do
  echo "=== $f ==="
  jq '{
    file: input_filename,
    purpose_len: (.analysis.session_purpose | length),
    effectiveness: .analysis.effectiveness.rating,
    highlights_count: (.analysis.highlights | length),
    has_rationale: (.analysis.effectiveness.rationale | length > 10),
    has_tool_patterns: (.analysis.tool_patterns.top_tools | length > 0)
  }' "$f"
done
```

**NG 判定基準**（1つでも該当すれば再分析対象）:

| チェック項目 | NG条件 | 根拠 |
|-------------|--------|------|
| session_purpose が汎用的 | 20文字以下、または「コマンド実行」「デプロイ作業」等の汎用フレーズのみ | JSONL を Read せずに L2 メタデータだけで生成した可能性 |
| highlights が空 | `highlights` が空配列 `[]` かつ `effectiveness.rating` が `high` | high 評価なのに highlight が1件もないのは矛盾 |
| rationale が浅い | `effectiveness.rationale` が20文字以下 | 根拠なしの評価は信頼できない |
| top_tools が空 | `tool_patterns.top_tools` が空配列 | L2 に tool_usage があるのに top_tools が空は分析漏れ |

**NG ファイルが検出された場合**: 該当セッションのみ L3 Agent を再実行する（Phase 2 に戻る）。再実行後、再度 Phase 3.5 を実行して品質を確認する。

**全件 OK の場合**: Phase 4 に進む。

### Phase 4: L4 日次サマリー生成

個別分析 JSON を **product/user/日付ごとにグループ化** し、それぞれに日次サマリーファイルを生成する。

#### 日次サマリーの構成

```markdown
# セッションログ日次サマリー — {YYYY-MM-DD}
**分析日**: {今日の日付}
**パイプライン**: L1→L2→L3→L4

## 1. データ概要
- 分析対象セッション数（L1通過 / 総数）
- ユーザー別分布（ユーザー名、セッション数、合計サイズ）

## 2. セッション一覧
| UUID | ユーザー | サイズ | 効果 | AI品質 | タグ |
（個別分析JSONから集計）

## 3. 今日のハイライト
| highlight 種別 | 検出数 | 該当セッション | 代表メッセージ |
| effective_tool_choice | ... | ... | ... |
| good_task_decomposition | ... | ... | ... |
| agent_delegation | ... | ... | ... |
| first_try_success | ... | ... | ... |
| clean_context | ... | ... | ... |
| recovery_skill | ... | ... | ... |
| documentation_habit | ... | ... | ... |
| new_technique | ... | ... | ... |
（検出ゼロの種別は行ごと省略）

## 4. トリガー検出サマリー
| トリガー種別 | 検出数 / 対象数 | 検出率 | 該当セッション |
| repeated_questions | ... | ...% | ... |
| repeated_tool_errors | ... | ...% | ... |
| session_abandoned | ... | ...% | ... |
| context_bloat | ... | ...% | ... |
| output_dissatisfaction | ... | ...% | ... |

## 5. ツール使用（全セッション集計）
- Top 5 ツールと使用回数

## 6. 手戻り・問題パターン
- 検出された手戻り件数
- 主な問題パターン（頻度順）

## 7. 改善提案
- 優先度付きの改善アクション一覧
```

出力先: `analysis/results/session-logs/daily/{product}/{user}/{YYYY-MM-DD}.md`

**複数の product/user/日付の組み合わせがある場合**: それぞれ別ファイルとして出力する。1回の実行で複数の日次サマリーが生成される。

> **週次・スプリント単位のトレンド分析** は `/session:weekly-trend` および `/session:sprint-trend` コマンドで実行する。

## 注意事項

- L1/L2 の結果は `/tmp/l2-results.jsonl` に一時保存（永続化不要）
- 個別分析 JSON は `analysis/results/session-logs/sessions/{product}/{user}/{date}/` 配下に永続保存
- 日次サマリーは `analysis/results/session-logs/daily/{product}/{user}/` 配下に永続保存
- 50+ セッションの場合、L3 は 5 並列 × 複数バッチで実行
- セッションログ自体は gitignore 対象（`analysis/session-logs/`）
- 分析結果も gitignore 対象（`analysis/results/`）
- 週次・スプリントのトレンドは別コマンド（`/session:weekly-trend`, `/session:sprint-trend`）で生成
