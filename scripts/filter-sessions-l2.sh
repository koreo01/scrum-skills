#!/bin/bash
# ============================================================================
# filter-sessions-l2.sh
# L2コンテンツ構造解析: L1通過セッションからツール使用統計・エラー・シグナルを抽出
# ============================================================================
#
# 【使用方法】
#   # L1の出力をパイプで受け取る（JSON形式）
#   ./scripts/filter-sessions-l1.sh --format json | ./scripts/filter-sessions-l2.sh
#
#   # 単体実行（ディレクトリ直接指定）
#   ./scripts/filter-sessions-l2.sh --input analysis/session-logs
#
#   # 特定セッション1件を解析
#   ./scripts/filter-sessions-l2.sh --file analysis/session-logs/air/user/2026-06-16/uuid.jsonl
#
# 【出力】
#   セッションごとの構造化JSON（1行1セッション = JSONL形式）
#   後段の集約分析でそのままRead可能
#

set -euo pipefail

# ============================================================================
# 定数
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_INPUT="$PROJECT_ROOT/analysis/session-logs"
JQ_FILTER="$SCRIPT_DIR/jq/l2-analyze.jq"

# カラー出力（stderr用）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ============================================================================
# 引数処理
# ============================================================================
INPUT_DIR=""
SINGLE_FILE=""
FROM_STDIN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            INPUT_DIR="$2"; shift 2 ;;
        --file)
            SINGLE_FILE="$2"; shift 2 ;;
        -h|--help)
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "L2コンテンツ構造解析でセッションの詳細メタデータを抽出します。"
            echo ""
            echo "入力（いずれか1つ）:"
            echo "  (stdin)           L1のJSON出力をパイプで受け取る"
            echo "  --input DIR       セッションログディレクトリ（L1フィルタなしで全件処理）"
            echo "  --file FILE       単一JSONLファイルを解析"
            echo ""
            echo "オプション:"
            echo "  -h, --help        このヘルプを表示"
            exit 0
            ;;
        *)
            echo -e "${RED}不明なオプション: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# stdin判定
if [ -z "$INPUT_DIR" ] && [ -z "$SINGLE_FILE" ] && [ ! -t 0 ]; then
    FROM_STDIN=true
fi

if [ "$FROM_STDIN" = false ] && [ -z "$INPUT_DIR" ] && [ -z "$SINGLE_FILE" ]; then
    INPUT_DIR="$DEFAULT_INPUT"
fi

# 前提条件チェック
if ! command -v jq &>/dev/null; then
    echo -e "${RED}jq がインストールされていません${NC}" >&2
    exit 1
fi

if [ ! -f "$JQ_FILTER" ]; then
    echo -e "${RED}jqフィルタファイルが見つかりません: $JQ_FILTER${NC}" >&2
    exit 1
fi

# ============================================================================
# 1セッション解析関数
# ============================================================================
analyze_session() {
    local filepath="$1"
    local product="${2:-}"
    local user="${3:-}"
    local date="${4:-}"
    local uuid="${5:-}"

    # パスからメタデータ推定（引数で渡されない場合）
    if [ -z "$product" ]; then
        local rel="${filepath#*session-logs/}"
        IFS='/' read -r product user date filename <<< "$rel"
        uuid="${filename%.jsonl}"
    fi

    local file_bytes
    file_bytes=$(wc -c < "$filepath" | tr -d ' ')

    # jqで構造解析（外部フィルタファイル使用）
    local analysis
    analysis=$(jq -s -f "$JQ_FILTER" "$filepath" 2>/dev/null) || {
        echo -e "  ${RED}FAIL${NC} $uuid (jq parse error)" >&2
        return 1
    }

    # メタデータを付与して出力（stdout）
    echo "$analysis" | jq -c \
        --arg product "$product" \
        --arg user "$user" \
        --arg date "$date" \
        --arg uuid "$uuid" \
        --argjson bytes "$file_bytes" \
        '. + {product: $product, user: $user, date: $date, uuid: $uuid, bytes: $bytes}'

    echo -e "  ${GREEN}OK${NC} $product/$user/$date/$uuid" >&2
}

# ============================================================================
# メイン処理
# ============================================================================
TOTAL=0
SUCCESS=0
FAILED=0

echo -e "${YELLOW}L2 コンテンツ構造解析${NC}" >&2

if [ -n "$SINGLE_FILE" ]; then
    analyze_session "$SINGLE_FILE"
    exit $?
fi

if [ "$FROM_STDIN" = true ]; then
    # stdinからL1 JSON出力を読み取り、pass判定のもののみ処理
    L1_DATA=$(cat)

    while IFS= read -r entry; do
        [ -z "$entry" ] && continue

        product=$(echo "$entry" | jq -r '.product')
        user=$(echo "$entry" | jq -r '.user')
        date=$(echo "$entry" | jq -r '.date')
        uuid=$(echo "$entry" | jq -r '.uuid')
        verdict=$(echo "$entry" | jq -r '.verdict')

        [ "$verdict" != "pass" ] && continue

        filepath="${DEFAULT_INPUT}/${product}/${user}/${date}/${uuid}.jsonl"
        if [ ! -f "$filepath" ]; then
            echo -e "  ${RED}NOT FOUND${NC} $filepath" >&2
            FAILED=$((FAILED + 1))
            continue
        fi

        TOTAL=$((TOTAL + 1))
        if analyze_session "$filepath" "$product" "$user" "$date" "$uuid"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done < <(echo "$L1_DATA" | jq -c '.[]' 2>/dev/null)
else
    # ディレクトリ直接スキャン
    while IFS= read -r filepath; do
        [ -z "$filepath" ] && continue
        TOTAL=$((TOTAL + 1))
        if analyze_session "$filepath"; then
            SUCCESS=$((SUCCESS + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done < <(find "$INPUT_DIR" -name "*.jsonl" -type f | sort)
fi

# サマリー
echo "" >&2
echo -e "${GREEN}L2解析完了${NC}" >&2
echo "  合計:   $TOTAL" >&2
echo -e "  成功:   ${GREEN}$SUCCESS${NC}" >&2
if [ "$FAILED" -gt 0 ]; then
    echo -e "  失敗:   ${RED}$FAILED${NC}" >&2
fi
