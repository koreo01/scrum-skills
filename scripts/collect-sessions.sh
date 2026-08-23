#!/bin/bash
# ============================================================================
# collect-sessions.sh
# GDrive上のClaude Codeセッションログ(.jsonl.gz)をダウンロード・展開する
# ============================================================================
#
# 【セットアップ】
#   1. brew install rclone
#   2. rclone config create gdrive drive scope drive.readonly
#      (ブラウザでGoogle認証)
#   3. chmod +x scripts/collect-sessions.sh
#
# 【使用方法】
#   # 今日のログを取得
#   ./scripts/collect-sessions.sh
#
#   # 日付範囲を指定
#   ./scripts/collect-sessions.sh --from 2026-06-12 --to 2026-06-17
#
#   # 特定ユーザーのみ
#   ./scripts/collect-sessions.sh --user your-username
#
#   # ドライラン（ダウンロードせずファイル一覧のみ表示）
#   ./scripts/collect-sessions.sh --dry-run
#
# 【出力先】
#   analysis/session-logs/{product}/{user}/{date}/{uuid}.jsonl
#

set -euo pipefail

# ============================================================================
# 定数
# ============================================================================
GDRIVE_ROOT_FOLDER_ID="1acgxQ3LB-rOhTSdVfU7q9EcetagdR-Zx"
RCLONE_REMOTE="gdrive"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/analysis/session-logs"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# 引数処理
# ============================================================================
FROM_DATE=""
TO_DATE=""
FILTER_USER=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)
            FROM_DATE="$2"; shift 2 ;;
        --to)
            TO_DATE="$2"; shift 2 ;;
        --user)
            FILTER_USER="$2"; shift 2 ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        --output)
            OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "GDrive上のClaude Codeセッションログをダウンロード・展開します。"
            echo ""
            echo "オプション:"
            echo "  --from DATE     開始日（YYYY-MM-DD、デフォルト: 今日）"
            echo "  --to DATE       終了日（YYYY-MM-DD、デフォルト: --from と同じ）"
            echo "  --user USER     特定ユーザーのみ取得"
            echo "  --output DIR    出力先ディレクトリ（デフォルト: analysis/session-logs/）"
            echo "  --dry-run       ダウンロードせずファイル一覧のみ表示"
            echo "  -h, --help      このヘルプを表示"
            exit 0
            ;;
        *)
            echo -e "${RED}不明なオプション: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# デフォルト: 今日
if [ -z "$FROM_DATE" ]; then
    FROM_DATE=$(date +%Y-%m-%d)
fi
if [ -z "$TO_DATE" ]; then
    TO_DATE="$FROM_DATE"
fi

# ============================================================================
# 前提条件チェック
# ============================================================================
echo -e "${BLUE}前提条件をチェック中...${NC}"

if ! command -v rclone &>/dev/null; then
    echo -e "${RED}rclone がインストールされていません${NC}" >&2
    echo "   brew install rclone" >&2
    echo "   rclone config create gdrive drive scope drive.readonly" >&2
    exit 1
fi
echo -e "  ${GREEN}OK${NC} rclone"

# rclone リモート確認
if ! rclone listremotes 2>/dev/null | grep -q "^${RCLONE_REMOTE}:"; then
    echo -e "${RED}rclone リモート '${RCLONE_REMOTE}' が設定されていません${NC}" >&2
    echo "   rclone config create gdrive drive scope drive.readonly" >&2
    exit 1
fi
echo -e "  ${GREEN}OK${NC} rclone remote '${RCLONE_REMOTE}'"

# GDrive 疎通確認
if ! rclone lsd --drive-root-folder-id "$GDRIVE_ROOT_FOLDER_ID" "${RCLONE_REMOTE}:" &>/dev/null; then
    echo -e "${RED}GDrive フォルダにアクセスできません${NC}" >&2
    echo "   フォルダID: $GDRIVE_ROOT_FOLDER_ID" >&2
    echo "   rclone config reconnect gdrive: で再認証してください" >&2
    exit 1
fi
echo -e "  ${GREEN}OK${NC} GDrive アクセス"

# ============================================================================
# メイン処理
# ============================================================================
echo ""
echo -e "${BLUE}セッションログを収集します${NC}"
echo "   期間:       $FROM_DATE ~ $TO_DATE"
echo "   ユーザー:   ${FILTER_USER:-全員}"
echo "   出力先:     $OUTPUT_DIR"
if [ "$DRY_RUN" = true ]; then
    echo -e "   モード:     ${YELLOW}ドライラン${NC}"
fi
echo ""

TOTAL_FILES=0
DOWNLOADED=0
SKIPPED=0
FAILED=0

# 一時ディレクトリ（.gz ダウンロード用）
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# rclone でファイル一覧を取得（product/user/date/file の4階層）
echo -e "${BLUE}GDrive フォルダを走査中...${NC}"
FILE_LIST=$(rclone lsf --drive-root-folder-id "$GDRIVE_ROOT_FOLDER_ID" \
    "${RCLONE_REMOTE}:" -R --files-only --format "ps" --separator "	" 2>/dev/null)

# 各ファイルを処理
CURRENT_SECTION=""
while IFS=$'\t' read -r filepath filesize; do
    [ -z "$filepath" ] && continue

    # .jsonl.gz のみ対象
    [[ "$filepath" != *.jsonl.gz ]] && continue

    # パスを分解: product/user/date/uuid.jsonl.gz
    IFS='/' read -r product user date filename <<< "$filepath"
    [ -z "$filename" ] && continue

    # ユーザーフィルタ
    if [ -n "$FILTER_USER" ] && [ "$user" != "$FILTER_USER" ]; then
        continue
    fi

    # 日付範囲フィルタ
    if [[ "$date" < "$FROM_DATE" || "$date" > "$TO_DATE" ]]; then
        continue
    fi

    UUID="${filename%.jsonl.gz}"
    LOCAL_DIR="$OUTPUT_DIR/$product/$user/$date"
    LOCAL_JSONL="$LOCAL_DIR/$UUID.jsonl"
    TOTAL_FILES=$((TOTAL_FILES + 1))

    # セクションヘッダ表示
    SECTION="$product/$user/$date"
    if [ "$SECTION" != "$CURRENT_SECTION" ]; then
        echo -e "  ${BLUE}[$SECTION]${NC}"
        CURRENT_SECTION="$SECTION"
    fi

    # 既にダウンロード済みならスキップ
    if [ -f "$LOCAL_JSONL" ]; then
        LOCAL_SIZE=$(wc -c < "$LOCAL_JSONL" | tr -d ' ')
        echo -e "    ${YELLOW}SKIP${NC} $UUID (${LOCAL_SIZE}B existing)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "    ${YELLOW}DRY${NC}  $UUID (${filesize}B gz)"
        continue
    fi

    # ダウンロード & 展開
    mkdir -p "$LOCAL_DIR"
    TMP_GZ="$TMPDIR/$filename"

    if rclone copyto --drive-root-folder-id "$GDRIVE_ROOT_FOLDER_ID" \
        "${RCLONE_REMOTE}:$filepath" "$TMP_GZ" 2>/dev/null; then
        if gunzip -c "$TMP_GZ" > "$LOCAL_JSONL" 2>/dev/null; then
            LINES=$(wc -l < "$LOCAL_JSONL" | tr -d ' ')
            SIZE=$(wc -c < "$LOCAL_JSONL" | tr -d ' ')
            echo -e "    ${GREEN}OK${NC}   $UUID (${SIZE}B, ${LINES} lines)"
            DOWNLOADED=$((DOWNLOADED + 1))
        else
            echo -e "    ${RED}FAIL${NC} $UUID (gunzip error)"
            rm -f "$LOCAL_JSONL"
            FAILED=$((FAILED + 1))
        fi
        rm -f "$TMP_GZ"
    else
        echo -e "    ${RED}FAIL${NC} $UUID (download error)"
        FAILED=$((FAILED + 1))
    fi
done <<< "$FILE_LIST"

# ============================================================================
# サマリー
# ============================================================================
echo ""
echo -e "${GREEN}完了${NC}"
echo "   対象ファイル: $TOTAL_FILES"
echo "   ダウンロード: $DOWNLOADED"
echo "   スキップ:     $SKIPPED (既存)"
echo "   失敗:         $FAILED"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo -e "${YELLOW}ドライランのため実際のダウンロードは行われていません。${NC}"
    echo "   実行するには --dry-run を外してください。"
fi

if [ "$DOWNLOADED" -gt 0 ]; then
    echo ""
    echo -e "${BLUE}出力先: $OUTPUT_DIR${NC}"
fi
