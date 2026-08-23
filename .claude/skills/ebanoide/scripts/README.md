# scripts/ ディレクトリ

## ファイル一覧

| ファイル | 説明 | ステータス |
|---|---|---|
| `extract_transcript.py` | .docx → 話者付きJSON抽出 | ✅ 実装済み |
| `pipeline.py` | メインパイプライン | ✅ 実装済み (一部TODO) |
| `slack_notify.py` | Slack DM 配信 | ✅ 実装済み |
| `gdrive_fetch.py` | Google Drive 連携 | ⬜ 未実装 (Phase 4) |

## 実行順序

```bash
# 単一議事録のテスト
python scripts/extract_transcript.py --input X.docx --output X.json --pretty
python scripts/pipeline.py --transcript X.docx --dry-run

# 本番運用
python scripts/pipeline.py  # 設定ファイルに従って全議事録を処理
```

## TODO（Claude Code で実装する箇所）

### pipeline.py 内のTODO

1. **slack_notify の有効化**
   - 冒頭の `from slack_notify import send_dm` のコメントアウトを外す
   - main 関数末尾の Slack 配信処理を有効化

2. **trend_data の本実装**
   - `build_trend_data()` 関数の中身を実装
   - `data/analysis_history/` 配下のJSONを読み込んで集計

3. **Tier ソート機能**
   - `process_transcript()` 内で、検出結果を Tier の高い順にソートしてから上限を適用

4. **pattern_id → pattern_name のマッピング**
   - `run_responder()` で `pattern_name` を正しく解決するマッピング辞書を追加

5. **Guard失敗時のリトライ**
   - Guard で NG だった場合、修正ヒントを Responder に渡して最大2回リトライ

### gdrive_fetch.py の新規実装

```python
# 期待される機能
def fetch_recent_transcripts(config: dict, date: str) -> list[Path]:
    """
    Google Drive の Meet Recordings フォルダから
    指定日に作成された .docx 議事録を取得し、
    ローカルパスのリストを返す
    """
```

## デバッグ・テスト

### サンプル議事録の準備

`tests/sample_transcripts/` に Gemini が生成した .docx 議事録を配置してください。
（このディレクトリは .gitignore に追加済み、コミットされません）

### テスト実行

```bash
# 1議事録だけテスト
python scripts/pipeline.py \
    --transcript tests/sample_transcripts/sample.docx \
    --dry-run

# 全議事録ディレクトリをテスト
python scripts/pipeline.py \
    --transcript-dir tests/sample_transcripts/ \
    --dry-run
```

### ログレベル変更

`config.yaml` の `logging.log_level` を `DEBUG` にすると詳細ログが出ます。
