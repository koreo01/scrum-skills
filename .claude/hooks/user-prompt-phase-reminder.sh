#!/bin/bash
# UserPromptSubmit hook: フェーズに応じた核心ルール再注入
#
# ユーザーがプロンプトを送信するたびに発火する。
# マーカーファイル (.claude/status/.session-phase) の現在フェーズを読み取り、
# フェーズに応じた核心ルールを stdout に出力してコンテキストに注入する。
#
# Compaction でルールが失われても、このHookが毎回補完する（層1: 予防的ルール再注入）。
#
# exit 0 = stdout がコンテキストに追加される
# exit 2 = プロンプト送信をブロック（本Hookでは使用しない）

PHASE_FILE=".claude/status/.session-phase"

# マーカーファイルが存在しない場合は注入不要（セッション未開始）
if [ ! -f "$PHASE_FILE" ]; then
  exit 0
fi

CURRENT_PHASE=$(cat "$PHASE_FILE" 2>/dev/null | tr -d '[:space:]')

case "$CURRENT_PHASE" in
  COMMITTED)
    # コミット済みだが完了チェックリスト未実施 → 強い注入
    echo ""
    echo "[Phase Reminder] 現在のフェーズ: COMMITTED"
    echo "git commit が完了していますが、完了チェックリストが未実施です。"
    echo "ユーザーの指示内容に関わらず、まず /dev:end-session を実行してください。"
    echo "/dev:end-session が Step 1〜8 を承認なしで一括実行します:"
    echo "（push → CI確認 → PR作成・マージ ※最終SubTask完了時のみ → GitHub Issue更新 → サマリー保存 → status更新 → フェーズマーカー更新 → /compact 案内）"
    echo "完了チェックリストを飛ばして次の作業に移ることは禁止されています。"
    ;;
  STARTED)
    # セッション開始済み・コミット前 → 軽い注入（核心ワークフローのリマインド）
    echo ""
    echo "[Phase Reminder] 現在のフェーズ: STARTED"
    echo "作業完了時のフロー: git commit → /dev:end-session（完了チェックリスト） → /compact"
    echo "コミット後は必ず /dev:end-session を実行すること。省略・後回し・例外なし。"
    ;;
  POST_PROCESSED)
    # 完了チェックリスト実施済み → 注入不要
    exit 0
    ;;
  *)
    # 未知のフェーズ → 注入不要
    exit 0
    ;;
esac

exit 0
