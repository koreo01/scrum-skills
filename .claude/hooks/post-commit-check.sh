#!/bin/bash
# PostToolUse hook: git commit後に完了チェックリストを促す

input=$(cat)
command=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)

if echo "$command" | grep -qE "git commit"; then
  # フェーズ状態マシン: COMMITTED に更新
  PHASE_FILE=".claude/status/.session-phase"
  PHASE_DIR=$(dirname "$PHASE_FILE")
  if [ -d "$PHASE_DIR" ]; then
    echo "COMMITTED" > "$PHASE_FILE"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "git commit を検出しました"
  echo "フェーズ状態: → COMMITTED"
  echo ""
  echo "次の作業に移る前に完了チェックリストを実施してください："
  echo "  /dev:end-session を実行（push → CI確認 → PR → GitHub Issue → サマリー → status更新）"
  echo ""
  echo "※ Stop Hook が有効です。完了チェックリスト未実施のまま停止しようとするとブロックされます。"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
