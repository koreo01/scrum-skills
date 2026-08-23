#!/bin/bash
# PreToolUse hook: MCP ツール呼び出し前に ToolSearch 確認リマインダーを注入
#
# Deferred Tools の仕組みにより、MCPツールはセッション開始時にツール名のみ登録され、
# パラメータスキーマは ToolSearch 実行後に初めてロードされる。
# ToolSearch なしで呼び出すとパラメータを推測し malformed error が発生する。
# チーム全体で頻発（W24-W25で複数検出）。

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MCP ツールを呼び出そうとしています。"
echo ""
echo "ToolSearch でスキーマを確認しましたか？"
echo "  - 未確認の場合、malformed error が発生します"
echo "  - 例: ToolSearch(\"select:mcp__claude_ai_Google_Drive__search_files\")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
