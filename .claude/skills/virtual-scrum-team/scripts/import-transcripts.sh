#!/bin/bash
# ============================================================================
# import-transcripts.sh
# Google Meets議事録(.docx)を取り込み、テキスト変換・フィラー削除を行う
# ============================================================================
#
# 【セットアップ】
#   1. brew install pandoc
#   2. mkdir -p ~/Downloads/meet-transcripts
#   3. chmod +x .claude/skills/virtual-scrum-team/scripts/import-transcripts.sh
#
# 【使用方法】
#   # プロジェクトルートから実行
#   ./.claude/skills/virtual-scrum-team/scripts/import-transcripts.sh
#
#   # 日付を指定（デフォルトは今日）
#   ./.claude/skills/virtual-scrum-team/scripts/import-transcripts.sh 2026-03-24
#
# 【ワークフロー】
#   1. Google Drive Web で議事録を選択 → ダウンロード（zip）
#   2. zipを ~/Downloads/meet-transcripts/ に展開
#   3. このスクリプトを実行
#   4. Claude Code で分析
#

set -e

# ============================================================================
# 設定
# ============================================================================
SOURCE_DIR=~/Downloads/meet-transcripts
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ANALYSIS_DIR="$PROJECT_ROOT/analysis/transcripts"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# 引数処理
# ============================================================================
TARGET_DATE="${1:-$(date +%Y-%m-%d)}"
YEAR=$(echo "$TARGET_DATE" | cut -d'-' -f1)
MONTH=$(echo "$TARGET_DATE" | cut -d'-' -f2)
DAY=$(echo "$TARGET_DATE" | cut -d'-' -f3)
WEEK=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%Y-W%V" 2>/dev/null || date -d "$TARGET_DATE" "+%Y-W%V")

# Google Meet ファイル名の日付形式: YYYY_MM_DD
DATE_PATTERN=$(echo "$TARGET_DATE" | tr '-' '_')

# 出力先ディレクトリ
RAW_DIR="$ANALYSIS_DIR/raw/$TARGET_DATE"
CONVERTED_DIR="$ANALYSIS_DIR/converted/$TARGET_DATE"
CLEANED_DAILY_DIR="$ANALYSIS_DIR/cleaned/daily/$TARGET_DATE"
CLEANED_WEEKLY_DIR="$ANALYSIS_DIR/cleaned/weekly/$WEEK"

# ============================================================================
# ヘルプ
# ============================================================================
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "使用方法: $0 [日付]"
    echo ""
    echo "Google Meetsからダウンロードした議事録(.docx)を処理します。"
    echo ""
    echo "引数:"
    echo "  日付    処理対象の日付（YYYY-MM-DD形式、デフォルト: 今日）"
    echo ""
    echo "処理フロー:"
    echo "  1. docx → raw/ にコピー"
    echo "  2. pandoc で txt に変換 → converted/"
    echo "  3. フィラー削除 → cleaned/daily/"
    echo "  4. 週フォルダにシンボリックリンク作成"
    echo ""
    echo "ソースフォルダ: $SOURCE_DIR"
    exit 0
fi

# ============================================================================
# 前提条件チェック
# ============================================================================
echo -e "${BLUE}📋 前提条件をチェック中...${NC}"

# pandoc チェック
if ! command -v pandoc &> /dev/null; then
    echo -e "${RED}❌ pandoc がインストールされていません${NC}"
    echo "   インストール: brew install pandoc"
    exit 1
fi
echo -e "  ${GREEN}✅${NC} pandoc"

# ソースディレクトリ
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${YELLOW}📁 ソースディレクトリを作成します: $SOURCE_DIR${NC}"
    mkdir -p "$SOURCE_DIR"
fi

# .docxファイル検索（サブディレクトリも含む）
DOCX_FILES_ALL=$(find "$SOURCE_DIR" -name "*.docx" -type f 2>/dev/null)
DOCX_COUNT_ALL=$(echo "$DOCX_FILES_ALL" | grep -c "." 2>/dev/null || echo 0)

if [ "$DOCX_COUNT_ALL" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $SOURCE_DIR に .docx ファイルがありません${NC}"
    echo ""
    echo "   以下の手順で進めてください："
    echo "   1. Google Drive Web で議事録を選択"
    echo "   2. 右クリック → ダウンロード（zipファイル）"
    echo "   3. zipを $SOURCE_DIR に展開"
    echo "   4. このスクリプトを再実行"
    exit 0
fi

# 指定日付（YYYY_MM_DD パターン）でフィルタリング
DOCX_FILES=$(echo "$DOCX_FILES_ALL" | grep "$DATE_PATTERN" || true)
DOCX_COUNT=$(echo "$DOCX_FILES" | grep -c "." 2>/dev/null || echo 0)
DOCX_SKIPPED=$(( DOCX_COUNT_ALL - DOCX_COUNT ))

if [ "$DOCX_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $TARGET_DATE の議事録が見つかりませんでした${NC}"
    echo "   ファイル名に \"${DATE_PATTERN}\" が含まれるファイルが対象です"
    echo ""
    echo "   フォルダ内のファイル一覧:"
    echo "$DOCX_FILES_ALL" | while IFS= read -r f; do
        echo "     $(basename "$f")"
    done
    exit 0
fi

echo -e "  ${GREEN}✅${NC} 処理対象: ${DOCX_COUNT} 個（フォルダ内 ${DOCX_COUNT_ALL} 個中、${DOCX_SKIPPED} 個は日付不一致でスキップ）"

# ============================================================================
# 確認プロンプト
# ============================================================================
echo ""
echo -e "${BLUE}🔄 以下の設定で処理を実行します：${NC}"
echo "   対象日付:     $TARGET_DATE （ファイル名パターン: ${DATE_PATTERN}）"
echo "   対象週:       $WEEK"
echo "   ソース:       $SOURCE_DIR （${DOCX_COUNT} / ${DOCX_COUNT_ALL} ファイルが対象）"
echo ""
echo "   出力先:"
echo "     raw:        $RAW_DIR"
echo "     converted:  $CONVERTED_DIR"
echo "     cleaned:    $CLEANED_DAILY_DIR"
echo ""
read -p "続行しますか？ (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "キャンセルしました。"
    exit 0
fi

# ============================================================================
# ディレクトリ作成
# ============================================================================
mkdir -p "$RAW_DIR"
mkdir -p "$CONVERTED_DIR"
mkdir -p "$CLEANED_DAILY_DIR"
mkdir -p "$CLEANED_WEEKLY_DIR"

# ============================================================================
# 処理実行
# ============================================================================
echo ""
echo -e "${BLUE}🔄 処理を開始します...${NC}"

PROCESSED=0
FAILED=0

while IFS= read -r docx_file; do
    [ -z "$docx_file" ] && continue
    
    filename=$(basename "$docx_file")
    echo -e "📄 処理中: ${filename}"
    
    # イベントタイプを推定
    event_type="meeting"
    filename_lower=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$filename_lower" == *"daily"* ]] || [[ "$filename_lower" == *"デイリー"* ]] || [[ "$filename_lower" == *"朝会"* ]]; then
        event_type="daily-scrum"
    elif [[ "$filename_lower" == *"retro"* ]] || [[ "$filename_lower" == *"振り返り"* ]]; then
        event_type="sprint-retro"
    elif [[ "$filename_lower" == *"review"* ]] || [[ "$filename_lower" == *"レビュー"* ]]; then
        event_type="sprint-review"
    elif [[ "$filename_lower" == *"planning"* ]] || [[ "$filename_lower" == *"プランニング"* ]]; then
        event_type="sprint-planning"
    elif [[ "$filename_lower" == *"refinement"* ]] || [[ "$filename_lower" == *"リファイン"* ]]; then
        event_type="refinement"
    fi
    
    # ベースファイル名
    base_name="${event_type}"
    
    # Step 1: raw/ にコピー
    raw_file="$RAW_DIR/${base_name}.docx"
    cp "$docx_file" "$raw_file"
    echo -e "  ${GREEN}✅${NC} raw/ にコピー"
    
    # Step 2: pandoc で変換
    converted_file="$CONVERTED_DIR/${base_name}.txt"
    if pandoc "$raw_file" -t plain -o "$converted_file" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} txt に変換"
    else
        echo -e "  ${RED}❌${NC} 変換失敗"
        ((FAILED++))
        continue
    fi
    
    # Step 3: フィラー削除
    cleaned_file="$CLEANED_DAILY_DIR/${base_name}.txt"
    "$SCRIPT_DIR/clean-fillers.sh" "$converted_file" "$cleaned_file"
    echo -e "  ${GREEN}✅${NC} フィラー削除"
    
    # Step 4: 週フォルダにシンボリックリンク
    day_of_week=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%a" 2>/dev/null | tr '[:upper:]' '[:lower:]' || date -d "$TARGET_DATE" "+%a" | tr '[:upper:]' '[:lower:]')
    weekly_link="$CLEANED_WEEKLY_DIR/${base_name}-${day_of_week}.txt"
    ln -sf "$cleaned_file" "$weekly_link" 2>/dev/null || true
    echo -e "  ${GREEN}✅${NC} 週フォルダにリンク作成"
    
    ((PROCESSED++))
    echo ""
    
done <<< "$DOCX_FILES"

# ============================================================================
# 完了
# ============================================================================
echo -e "${GREEN}✅ 処理完了${NC}"
echo "   処理成功: ${PROCESSED} ファイル"
echo "   処理失敗: ${FAILED} ファイル"
echo ""
echo -e "${BLUE}📁 出力先:${NC}"
echo "   $CLEANED_DAILY_DIR"
echo ""
echo -e "${BLUE}📊 次のステップ:${NC}"
echo "   Claude Code で以下を実行:"
echo "   @.claude/analysis/transcripts/cleaned/daily/$TARGET_DATE/daily-scrum.txt を分析してください"
echo ""

# ソースファイル削除確認
read -p "ソースファイルを削除しますか？ (y/N): " DELETE_CONFIRM
if [[ "$DELETE_CONFIRM" =~ ^[Yy]$ ]]; then
    rm -rf "$SOURCE_DIR"/*
    echo -e "${GREEN}✅${NC} ソースファイルを削除しました"
fi
