#!/bin/bash
# ============================================================================
# filter-sessions-l1.sh
# L1メタデータスキャン: トリビアルセッションを除外し、分析対象一覧を出力する
# ============================================================================
#
# 【使用方法】
#   # デフォルト（analysis/session-logs/ を走査）
#   ./scripts/filter-sessions-l1.sh
#
#   # 入力ディレクトリ指定
#   ./scripts/filter-sessions-l1.sh --input /path/to/session-logs
#
#   # 閾値カスタマイズ
#   ./scripts/filter-sessions-l1.sh --min-lines 30 --min-bytes 10000
#
#   # JSON出力（後段パイプライン用）
#   ./scripts/filter-sessions-l1.sh --format json
#
# 【出力】
#   分析対象セッション一覧（CSV or JSON）
#   デフォルト出力先: stdout
#

set -euo pipefail

# ============================================================================
# 定数・デフォルト値
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_INPUT="$PROJECT_ROOT/analysis/session-logs"

# フィルタ閾値
MIN_LINES=20
MIN_BYTES=5000   # 展開後のJSONLサイズ（≒ gz 5KB相当）

# 出力形式
FORMAT="csv"  # csv or json

# カラー出力（stderr用）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# 引数処理
# ============================================================================
INPUT_DIR="$DEFAULT_INPUT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            INPUT_DIR="$2"; shift 2 ;;
        --min-lines)
            MIN_LINES="$2"; shift 2 ;;
        --min-bytes)
            MIN_BYTES="$2"; shift 2 ;;
        --format)
            FORMAT="$2"; shift 2 ;;
        -h|--help)
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "L1メタデータスキャンでトリビアルセッションを除外します。"
            echo ""
            echo "オプション:"
            echo "  --input DIR       入力ディレクトリ（デフォルト: analysis/session-logs/）"
            echo "  --min-lines N     最小JSONL行数（デフォルト: $MIN_LINES）"
            echo "  --min-bytes N     最小ファイルサイズ（デフォルト: $MIN_BYTES）"
            echo "  --format FORMAT   出力形式: csv or json（デフォルト: csv）"
            echo "  -h, --help        このヘルプを表示"
            exit 0
            ;;
        *)
            echo -e "${RED}不明なオプション: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# ============================================================================
# 前提条件チェック
# ============================================================================
if [ ! -d "$INPUT_DIR" ]; then
    echo -e "${RED}入力ディレクトリが存在しません: $INPUT_DIR${NC}" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo -e "${RED}jq がインストールされていません${NC}" >&2
    echo "  brew install jq" >&2
    exit 1
fi

# ============================================================================
# メイン処理
# ============================================================================
TOTAL=0
PASSED=0
EXCLUDED=0

# JSON出力用の配列開始
if [ "$FORMAT" = "json" ]; then
    echo "["
    FIRST_JSON=true
else
    # CSVヘッダ
    echo "product,user,date,uuid,bytes,lines,assistant_count,user_count,verdict"
fi

while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue

    # パスからメタデータ抽出: .../product/user/date/uuid.jsonl
    rel_path="${filepath#"$INPUT_DIR/"}"
    IFS='/' read -r product user date filename <<< "$rel_path"
    uuid="${filename%.jsonl}"

    TOTAL=$((TOTAL + 1))

    # L1-1: ファイルサイズ
    file_bytes=$(wc -c < "$filepath" | tr -d ' ')

    # L1-2: 行数
    file_lines=$(wc -l < "$filepath" | tr -d ' ')

    # L1-3: assistantメッセージ数（jq で高速カウント）
    assistant_count=$(jq -r 'select(.type == "assistant") | .type' "$filepath" 2>/dev/null | wc -l | tr -d ' ')

    # L1-4: userメッセージ数
    user_count=$(jq -r 'select(.type == "user") | .type' "$filepath" 2>/dev/null | wc -l | tr -d ' ')

    # 判定
    verdict="pass"
    reason=""

    if [ "$file_bytes" -lt "$MIN_BYTES" ]; then
        verdict="exclude"
        reason="bytes<${MIN_BYTES}"
    elif [ "$file_lines" -lt "$MIN_LINES" ]; then
        verdict="exclude"
        reason="lines<${MIN_LINES}"
    elif [ "$assistant_count" -eq 0 ]; then
        verdict="exclude"
        reason="no_assistant"
    fi

    if [ "$verdict" = "pass" ]; then
        PASSED=$((PASSED + 1))
    else
        EXCLUDED=$((EXCLUDED + 1))
    fi

    # 出力
    if [ "$FORMAT" = "json" ]; then
        if [ "$FIRST_JSON" = true ]; then
            FIRST_JSON=false
        else
            echo ","
        fi
        printf '  {"product":"%s","user":"%s","date":"%s","uuid":"%s","bytes":%d,"lines":%d,"assistant_count":%d,"user_count":%d,"verdict":"%s"' \
            "$product" "$user" "$date" "$uuid" "$file_bytes" "$file_lines" "$assistant_count" "$user_count" "$verdict"
        if [ -n "$reason" ]; then
            printf ',"reason":"%s"}' "$reason"
        else
            printf '}'
        fi
    else
        echo "$product,$user,$date,$uuid,$file_bytes,$file_lines,$assistant_count,$user_count,$verdict"
    fi
done < <(find "$INPUT_DIR" -name "*.jsonl" -type f | sort)

# JSON配列終了
if [ "$FORMAT" = "json" ]; then
    echo ""
    echo "]"
fi

# サマリー（stderrに出力）
echo "" >&2
echo -e "${GREEN}L1フィルタリング完了${NC}" >&2
echo "  合計:   $TOTAL" >&2
echo -e "  通過:   ${GREEN}$PASSED${NC}" >&2
echo -e "  除外:   ${YELLOW}$EXCLUDED${NC}" >&2
if [ "$TOTAL" -gt 0 ]; then
    pct=$((EXCLUDED * 100 / TOTAL))
    echo "  除外率: ${pct}%" >&2
fi
