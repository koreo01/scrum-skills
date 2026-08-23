# ブランチ作成前チェックリスト

新しい Task ブランチを切る前に必ずこの手順を実行する。**省略・後回し・例外なし。**

> ℹ️ **本チェックリストは `/dev:start-session` と Pre-ToolUse フック（`.claude/hooks/pre-bash-branch-source-check.sh`）により自動化されている。**
> - `/dev:start-session` が条件②（origin/main 最新化・前 Task マージ済み・同一 Task ブランチ上の継続作業）を自動チェックし、未マージコミット検出時は **ケースA** として停止する
> - main 以外からの `git checkout -b` は Pre-ToolUse フックが自動ブロックする
>
> 以下は **手動チェック手順としての参照**（自動化が想定外の状態を検出した場合の確認用、または `/dev:start-session` を経由せずブランチを切る場合の手順）として残す。

---

## Step 1: origin/main を最新化して確認する

```bash
git fetch origin
git log origin/main --oneline -3
```

前 Task のマージコミットが origin/main に含まれているか確認する。

| 確認結果 | 対応 |
|---------|------|
| マージコミットが存在する | Step 2 へ進む |
| マージコミットが存在しない | ユーザーに報告・待機する（PR マージ前に次の作業を開始しない） |

---

## Step 2: main に切り替えて pull する

```bash
git checkout main
git pull origin main
```

---

## Step 3: ブランチを作成する

```bash
git checkout -b chore/{TaskID}_{英語サマリー}
```

> ℹ️ フォーマット・許可された source branch は `.claude/config/ticket-system.json` の `branchNaming.formats` / `branchNaming.sourceBranch` 参照。他組織で流用する際は同 Config を書き換える。

- **現在地が main であることを確認してからコマンドを実行する**
- 作業ブランチから別の作業ブランチを派生させない（GitHubFlow 違反）

---

## NG パターン

```bash
# ❌ 作業ブランチから派生
(chore/{TaskA}...) $ git checkout -b chore/{TaskB}...

# ✅ main から派生
(main) $ git checkout -b chore/{TaskB}...
```
