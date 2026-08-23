# CI 品質ゲート & Branch Protection 設定ガイド

## 概要

ローカル Hook（即時フィードバック）+ GitHub Actions CI（最終防衛線）の2層構成で、main ブランチの品質を保証する。

```
開発者 → git push → [Local Hook] → remote branch → [CI] → PR → [Branch Protection] → main
                      即時チェック                    網羅チェック    マージ制御
```

## GitHub Actions ワークフロー

ファイル: `.github/workflows/quality-gate.yml`

### トリガー

| イベント | 対象 |
|---------|------|
| push | main 以外の全ブランチ |
| pull_request | main 向け |

### チェック項目

| チェック | 内容 | 失敗時 |
|---------|------|--------|
| コミットメッセージ形式 | `[#xxx]` または `[#xxx/#yyy]` パターン必須 | CI 失敗 |
| シェルスクリプト構文 | 全 `.sh` ファイルに `bash -n` 実行 | CI 失敗 |
| project-checks | `.claude/hooks/project-checks.sh` があれば実行 | CI 失敗 |

## Branch Protection Rule 設定手順

GitHub リポジトリの Settings > Branches から設定する。

### 1. ルール作成

1. **Settings** > **Branches** > **Add branch ruleset** をクリック
2. **Ruleset Name**: `main-protection`
3. **Enforcement status**: `Active`
4. **Target branches**: `main` を追加

### 2. 必須ルール

以下のルールを有効化する:

| ルール | 設定値 | 説明 |
|-------|--------|------|
| Require a pull request before merging | ON | PR なしの直接マージを禁止 |
| Required approvals | 0（任意） | レビュー承認の必要数 |
| Require status checks to pass | ON | CI 通過を必須化 |
| Status checks that are required | `quality-gate` | ワークフローのジョブ名 |
| Block force pushes | ON | force push を禁止 |
| Require linear history | OFF（任意） | マージコミット許可 |

### 3. Status Check の追加

**Require status checks to pass** を有効化後:

1. **Add checks** をクリック
2. 検索ボックスに `quality-gate` と入力
3. 表示される `quality-gate` を選択して追加

> **注意**: Status Check は少なくとも1回 CI が実行された後でないと検索結果に表示されない。先にブランチを push して CI を走らせてから設定する。

### 4. 設定確認

設定完了後、以下を確認:

- main への直接 push が拒否されること
- PR 作成時に CI が自動実行されること
- CI 失敗時にマージボタンが無効化されること

## ローカル Hook との役割分担

| チェック | ローカル Hook | CI |
|---------|-------------|-----|
| current.md 鮮度 | o | - |
| 未コミット変更 | o | - |
| コミットメッセージ形式 | - | o |
| シェルスクリプト構文 | o（差分のみ） | o（全ファイル） |
| project-checks | o | o |

ローカル Hook は Claude Code 経由の操作にのみ有効。CI は全ユーザー・全経路で強制される。
