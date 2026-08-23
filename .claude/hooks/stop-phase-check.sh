#!/bin/bash
# Stop hook: フェーズ状態マシンによるターン終了検証
#
# Claude がターンを終了しようとするたびに発火する。
# マーカーファイル (.claude/status/.session-phase) の現在フェーズを読み取り、
# 完了チェックリストを実施せずに停止しようとしている場合に exit 2 でブロックする。
#
# フェーズ順序: STARTED → COMMITTED → POST_PROCESSED → (クリア)
#
# exit 0 = 停止を許可
# exit 2 = 停止をブロック（Claude に続行を強制）

# --- stdin から入力を読み取り、stop_hook_active を確認 ---
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(str(d.get('stop_hook_active', False)).lower())
except Exception:
    print('false')
" 2>/dev/null)

# 前回のブロックによる再発火の場合は即座に停止を許可（無限ループ防止）
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

PHASE_FILE=".claude/status/.session-phase"

# マーカーファイルが存在しない場合はチェック不要（セッション未開始）
if [ ! -f "$PHASE_FILE" ]; then
  exit 0
fi

CURRENT_PHASE=$(cat "$PHASE_FILE" 2>/dev/null | tr -d '[:space:]')

case "$CURRENT_PHASE" in
  COMMITTED)
    # コミット済みだが完了チェックリスト未実施 → ブロック
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "フェーズ状態マシン: 停止をブロックしました"
    echo ""
    echo "現在のフェーズ: COMMITTED"
    echo "git commit が完了していますが、完了チェックリストが未実施です。"
    echo ""
    echo "次のアクション:"
    echo "  /dev:end-session を実行して完了チェックリストを実施してください。"
    echo "  （push → CI確認 → PR → GitHub Issue更新 → サマリー保存 → status更新）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 2
    ;;
  STARTED|POST_PROCESSED|"")
    # セッション開始済み・コミット前 / 完了チェックリスト実施済み / 空 → 停止許可
    exit 0
    ;;
  *)
    # 未知のフェーズ → 警告のみで停止許可
    echo ""
    echo "警告: 不明なフェーズ状態 '${CURRENT_PHASE}' が検出されました。"
    echo "マーカーファイル (${PHASE_FILE}) を確認してください。"
    exit 0
    ;;
esac
