#!/bin/bash
# PreToolUse hook: git push 前の品質ゲート
#
# NGの場合 exit 2 で hookがブロックする。
# OKの場合 exit 0 で push が続行される。
#
# チェック項目:
#   1. current.md がコミットに含まれる更新を反映しているか（最終更新の鮮度）
#   2. 未コミットの変更がないか（クリーンな状態でpush）
#   3. シェルスクリプトの構文チェック（該当ファイルがステージされている場合）
#   4. プロジェクト固有チェック（.claude/hooks/project-checks.sh があれば実行）

set -euo pipefail

ERRORS=()
WARNINGS=()

# --- stdin からツール入力を読み取る ---
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

# git push 以外は無視
if ! echo "$COMMAND" | grep -qE "git push"; then
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "品質ゲートチェック（pre-push）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Check 1: current.md の鮮度 ---
CURRENT_MD=".claude/status/current.md"
if [ -f "$CURRENT_MD" ]; then
  # 最新コミットの時刻と current.md の更新時刻を比較
  LAST_COMMIT_TS=$(git log -1 --format=%ct 2>/dev/null || echo "0")
  CURRENT_MD_TS=$(stat -f %m "$CURRENT_MD" 2>/dev/null || stat -c %Y "$CURRENT_MD" 2>/dev/null || echo "0")

  if [ "$CURRENT_MD_TS" -lt "$LAST_COMMIT_TS" ]; then
    WARNINGS+=("current.md が最新コミットより古い可能性があります。更新を確認してください。")
  else
    echo "  [OK] current.md は最新コミット以降に更新済み"
  fi
else
  WARNINGS+=("current.md が存在しません。")
fi

# --- Check 2: 未コミットの変更 ---
if [ -n "$(git status --porcelain 2>/dev/null | grep -v '^\?\?')" ]; then
  WARNINGS+=("未コミットの変更があります。意図的なものか確認してください。")
else
  echo "  [OK] ワーキングツリーはクリーン"
fi

# --- Check 3: ステージ済みシェルスクリプトの構文チェック ---
CHANGED_SCRIPTS=$(git diff --name-only origin/main...HEAD 2>/dev/null | grep '\.sh$' || true)
if [ -n "$CHANGED_SCRIPTS" ]; then
  SCRIPT_ERRORS=0
  while IFS= read -r script; do
    if [ -f "$script" ]; then
      if ! bash -n "$script" 2>/dev/null; then
        ERRORS+=("シェルスクリプト構文エラー: $script")
        SCRIPT_ERRORS=$((SCRIPT_ERRORS + 1))
      fi
    fi
  done <<< "$CHANGED_SCRIPTS"
  if [ "$SCRIPT_ERRORS" -eq 0 ]; then
    echo "  [OK] シェルスクリプト構文チェック通過（${CHANGED_SCRIPTS}）"
  fi
else
  echo "  [--] シェルスクリプトの変更なし（スキップ）"
fi

# --- Check 4: プロジェクト固有チェック ---
PROJECT_CHECKS=".claude/hooks/project-checks.sh"
if [ -f "$PROJECT_CHECKS" ] && [ -x "$PROJECT_CHECKS" ]; then
  echo "  プロジェクト固有チェックを実行中..."
  if ! bash "$PROJECT_CHECKS"; then
    ERRORS+=("プロジェクト固有チェックが失敗しました。")
  else
    echo "  [OK] プロジェクト固有チェック通過"
  fi
else
  echo "  [--] プロジェクト固有チェックなし（スキップ）"
fi

# --- 結果出力 ---
echo ""

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "警告:"
  for w in "${WARNINGS[@]}"; do
    echo "  - $w"
  done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "エラー（push をブロック）:"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "品質ゲート: NG — 上記エラーを修正してから再度 push してください。"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 2
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "品質ゲート: OK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
