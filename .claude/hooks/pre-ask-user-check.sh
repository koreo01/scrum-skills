#!/bin/bash
# PreToolUse hook: AskUserQuestion の前に自己確認リマインダーを注入
#
# Claudeが「自分で確認できること」をユーザーに質問するパターンを抑制する。
# セッション分析で3セッション・4回検出された頻発パターン。
# Compactionで失われないよう、Hookで毎回注入する。

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "AskUserQuestion を実行しようとしています。"
echo ""
echo "以下を自問してください:"
echo "  - この情報は git log / git status / ls / find 等で自分で取得できませんか？"
echo "  - PR/ブランチのマージ状態は gh pr view で確認できませんか？"
echo "  - 自分が生成したファイルの場所を Glob/find で確認できませんか？"
echo ""
echo "自分で確認できる情報をユーザーに質問してはいけません。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
