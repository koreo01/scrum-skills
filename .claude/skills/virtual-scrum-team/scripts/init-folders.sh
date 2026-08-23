#!/bin/bash
# ============================================================================
# init-folders.sh
# 議事録分析用のフォルダ構造を初期化する
# ============================================================================
#
# 【使用方法】
#   ./.claude/skills/virtual-scrum-team/scripts/init-folders.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# カラー
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📁 フォルダ構造を初期化します...${NC}"

# analysis/transcripts
mkdir -p "$PROJECT_ROOT/analysis/transcripts/raw"
mkdir -p "$PROJECT_ROOT/analysis/transcripts/converted"
mkdir -p "$PROJECT_ROOT/analysis/transcripts/cleaned/daily"
mkdir -p "$PROJECT_ROOT/analysis/transcripts/cleaned/weekly"
mkdir -p "$PROJECT_ROOT/analysis/transcripts/cleaned/events/retro"
mkdir -p "$PROJECT_ROOT/analysis/transcripts/cleaned/events/review"
mkdir -p "$PROJECT_ROOT/analysis/transcripts/cleaned/events/planning"

# analysis/results
mkdir -p "$PROJECT_ROOT/analysis/results/daily"
mkdir -p "$PROJECT_ROOT/analysis/results/weekly"
mkdir -p "$PROJECT_ROOT/analysis/results/monthly"

# ソースディレクトリ
mkdir -p ~/Downloads/meet-transcripts

echo -e "${GREEN}✅ フォルダ構造を作成しました${NC}"
echo ""
echo "作成されたフォルダ:"
echo ""
find "$PROJECT_ROOT/analysis" -type d | sed "s|$PROJECT_ROOT/||" | sort
echo ""
echo "ソースフォルダ:"
echo "  ~/Downloads/meet-transcripts/"
