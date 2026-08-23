#!/bin/bash
# PreToolUse hook: git commit のメッセージにチケット ID prefix を含むか検証
#
# CLAUDE.md「コミットメッセージ」規約の自動強制。
# `git commit` コマンドのみ対象。検査パターンは
# .claude/config/ticket-system.json の commitMessage.pattern を参照する
# （他組織で流用する際は同 Config を書き換えるだけで対応できる）。
# パターン非該当の場合 permissionDecision: deny を返してコミットをブロックする。

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

if echo "$cmd" | grep -qE '^git commit'; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  config_path="${repo_root}/.claude/config/ticket-system.json"
  pattern=$(jq -r '.commitMessage.pattern' "$config_path")
  example=$(jq -r '.commitMessage.examples.withSubTask' "$config_path")

  if ! echo "$cmd" | grep -qE "$pattern"; then
    jq -n --arg ex "$example" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":("コミットメッセージにチケット ID prefix が含まれていません。例: " + $ex)}}'
  fi
fi
