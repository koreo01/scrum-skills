#!/bin/bash
# PreToolUse hook: git checkout -b は所定の source branch からのみ実行可能とする
#
# CLAUDE.md「ブランチ名フォーマット」および
# .claude/rules/branch-checklist.md「Step 3 NG パターン」の自動強制。
# 作業ブランチから別の作業ブランチを派生させる（GitHubFlow 違反）を防ぐ。
# source branch は .claude/config/ticket-system.json の branchNaming.sourceBranch を参照する
# （他組織で流用する際は同 Config を書き換えるだけで対応できる）。

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

if echo "$cmd" | grep -qE '^git checkout -b'; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  config_path="${repo_root}/.claude/config/ticket-system.json"
  source_branch=$(jq -r '.branchNaming.sourceBranch' "$config_path")

  current_branch=$(git branch --show-current 2>/dev/null)
  if [ "$current_branch" != "$source_branch" ]; then
    jq -n --arg sb "$source_branch" --arg b "$current_branch" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":("git checkout -b は " + $sb + " からのみ実行できます。現在地: " + $b + "\n手順: .claude/rules/branch-checklist.md を参照してください。")}}'
  fi
fi
