# /dev:end-session — 開発セッション終了チェックリスト

CLAUDE.md「完了チェックリストの進め方」に基づき、
1SubTask 完了後の手順を**一括実行**します。

---

## 前提条件

このコマンドはコミット完了後に実行します。コミット前に実行しないでください。

---

## ワークフロー

**全ステップを承認なしで一括実行し、完了後に結果を報告します。異常があった場合のみユーザーに確認を求めます。**

### Step 0: 完了SubTaskの特定と残SubTask判定

`status/current.md` を読み込み、完了したSubTaskを特定します。
さらに、**他に「⏳ 待機中」の SubTask が残っているか**を確認し、今回が「途中SubTask完了」か「最終SubTask完了」かを判定します。

次のフォーマットで一括実行を開始することを宣言します:

**途中SubTask完了の場合**（待機中SubTaskが残っている）:
```
完了チェックリストを一括実行します。

完了したSubTask: {#xxx} {タイトル}
残りSubTask: {N}件（途中SubTask完了 → PR作成・マージはスキップ）

実行内容:
  1. git push
  2. CI 結果確認（失敗時は自動修正・再push）
  3. GitHub Issue 更新（SubTask → Close）
  4. 作業履歴 MD 出力（save-summary）
  5. status/current.md 更新
```

**最終SubTask完了の場合**（全SubTaskが Done になる）:
```
完了チェックリストを一括実行します。

完了したSubTask: {#xxx} {タイトル}
残りSubTask: なし（最終SubTask完了 → PR作成・マージを実行）

実行内容:
  1. git push
  2. CI 結果確認（失敗時は自動修正・再push）
  3. PR 作成（既存PRがなければ自動作成）
  4. PR マージ・ブランチ削除
  5. GitHub Issue 更新（SubTask → Close）
  6. 作業履歴 MD 出力（save-summary）
  7. status/current.md 更新
```

宣言後、承認を待たずに Step 1 へ進みます。

---

### Step 1: git push

現在のブランチをリモートに push します。

```bash
git push
```

追跡ブランチが未設定の場合は以下を実行します:

```bash
git push -u origin {現在のブランチ名}
```

**品質ゲート Hook（pre-push-quality-gate.sh）が自動実行されます。NGの場合は push がブロックされるため、エラー内容を修正してから再実行してください。**

---

### Step 2: CI 結果確認

push 後に GitHub Actions CI（Quality Gate）の実行結果を確認します。

#### 2-1. CI 実行の待機

```bash
gh run list --branch {現在のブランチ名} --limit 1 --json databaseId,status,conclusion,event --jq '.[0]'
```

status が `completed` でない場合は `gh run watch` で完了を待機します:

```bash
gh run watch {run_id} --exit-status
```

#### 2-2. 結果判定

- **成功**（conclusion: success）→ Step 3 へ進む（途中SubTask完了の場合は Step 3-4 をスキップし Step 5 へ）
- **失敗**（conclusion: failure）→ Step 2-3 へ

#### 2-3. CI エラーの自動修正

失敗した run のログを取得してエラー内容を解析します:

```bash
gh run view {run_id} --log 2>&1 | grep -E "(NG:|ERROR:)"
```

エラー内容を分析し、修正可能な場合は以下のフローを実行します:

1. エラー原因を特定し、該当ファイルを修正する
2. 修正をコミットする（コミットメッセージは元の SubTask の `[#xxx/#yyy]` 形式（`.claude/config/ticket-system.json` の `commitMessage.formats` 参照）を維持）
3. 再 push する（Step 1 に戻る）
4. 再度 CI 結果を確認する（Step 2-1 に戻る）

**リトライ上限**: 最大2回まで。2回修正しても CI が通らない場合はユーザーに報告して停止する。

修正不可能なエラー（インフラ障害等）の場合はユーザーに報告して停止する。

---

### Step 3: PR 作成（最終SubTask完了時のみ）

> **途中SubTask完了の場合はこのステップをスキップし、Step 5 へ進む。**

現在のブランチで main 向けの PR が存在するか確認し、なければ自動作成します。

```bash
gh pr view --json number 2>/dev/null
```

PR が存在しない場合は以下で作成します:

```bash
gh pr create --base main --title "{コミットメッセージの要約}" --body "..."
```

**PR タイトル**: 親Task/Storyのタイトルを反映（70文字以内）
**PR ボディ**: ブランチの全コミット（全SubTask分）を要約した Summary + Test plan セクション

既に PR が存在する場合はこのステップをスキップします。

---

### Step 4: PR マージ・ブランチ削除（最終SubTask完了時のみ）

> **途中SubTask完了の場合はこのステップをスキップし、Step 5 へ進む。**

PR を main にマージし、リモート・ローカルのブランチを削除します。

#### 4-1. PR マージ

```bash
gh pr merge --merge --delete-branch
```

`--merge` でマージコミットを作成し、`--delete-branch` でリモートブランチを自動削除します。

#### 4-2. ローカルブランチの整理

マージ完了後、main に切り替えてローカルを最新化し、作業ブランチを削除します:

```bash
git checkout main && git pull origin main && git branch -d {作業ブランチ名}
```

#### 4-3. マージ失敗時の対応

- **CI 未完了でマージがブロックされた場合**: CI 完了を待ってからリトライする
- **マージコンフリクトの場合**: ユーザーに報告して停止する
- **その他のエラー**: ユーザーに報告して停止する

---

### Step 5: GitHub Issue 更新

対象 SubTask の GitHub Issue を更新します。

```bash
gh issue close {SubTask番号} --comment "完了日時: {現在の日時（JST）}"
```

更新内容:
- Issue を Close（`ステータス` → `Done` 相当）
- コメントに `完了日時` → 現在の日時（JST）を記録

---

### Step 6: 作業履歴 MD 出力

`save-summary` スキルを使って作業サマリーを保存します。

保存先: `.claude/summaries/YYYY-MM-DD_{チケット番号}_{説明}.md`

---

### Step 7: status/current.md 更新

完了した SubTask を Done に更新し、次のアクションと引き継ぎ情報を記載します。

更新内容:
- 対象 SubTask の状態を `Done` に変更
- 次の待機中 SubTask があれば「次のアクション」を更新
- 全 SubTask が完了の場合は「次のアクション」に Task 完了処理（PR 作成等）を記載
- 「引き継ぎ情報」セクションを更新する（下記ルール参照）

#### 引き継ぎ情報の更新ルール

Compaction を跨いで次セッションの Claude が参照すべき情報を記載する。
save-summary の「主な意思決定」を参照し、次の観点で抽出・転記する:

- 技術的な前提状態（修正済み・未対応など）
- ユーザーが指摘・拒否した選択肢とその理由
- Claude が犯したミスとその修正（同種ミス防止）
- 未解決の疑問・次セッションで確認が必要な事項

全 SubTask 完了時はセクションをクリアし「なし」と明記する。

---

### Step 8: フェーズマーカー更新

フェーズを POST_PROCESSED に更新します。

```bash
echo "POST_PROCESSED" > .claude/status/.session-phase
```

---

### Step 9: 完了レポート

全ステップ完了後、結果を一括報告します。

**途中SubTask完了の場合**:
```
完了チェックリスト — 全ステップ完了（途中SubTask）

  [OK] git push（origin/{ブランチ名}）
  [OK] CI 結果確認（Quality Gate: success）または [OK] CI 自動修正（{N}回リトライ）
  [SKIP] PR 作成（残SubTaskあり）
  [SKIP] PR マージ（残SubTaskあり）
  [OK] GitHub Issue 更新（#xxx → Close）
  [OK] 作業履歴 MD 出力（.claude/summaries/...）
  [OK] status/current.md 更新
  [OK] フェーズマーカー更新（→ POST_PROCESSED）

次のアクション:
  {更新後の次のアクション内容}

/compact を実行して会話履歴を圧縮してください。
次のセッションは /dev:start-session から開始します。
```

**最終SubTask完了の場合**:
```
完了チェックリスト — 全ステップ完了（Task/Story完了）

  [OK] git push（origin/{ブランチ名}）
  [OK] CI 結果確認（Quality Gate: success）または [OK] CI 自動修正（{N}回リトライ）
  [OK] PR 作成（#{PR番号}）または [SKIP] 既存PR あり
  [OK] PR マージ・ブランチ削除（main にマージ済み）
  [OK] GitHub Issue 更新（#xxx → Close）
  [OK] 作業履歴 MD 出力（.claude/summaries/...）
  [OK] status/current.md 更新
  [OK] フェーズマーカー更新（→ POST_PROCESSED）

次のアクション:
  {更新後の次のアクション内容}

/compact を実行して会話履歴を圧縮してください。
次のセッションは /dev:start-session から開始します。
```

---

## 異常時の処理

いずれかのステップでエラーが発生した場合:

1. エラーが発生したステップで停止する
2. エラー内容をユーザーに報告する
3. ユーザーの指示を待つ

```
完了チェックリスト — Step {N} でエラーが発生しました。

完了済み:
  {完了済みのステップ一覧}

エラー:
  Step {N}: {エラー内容}

未実行:
  {未実行のステップ一覧}

対応方法を指示してください。
```

---

## 根拠

- CLAUDE.md「チケット作業の完了チェックリスト」（コミット・プッシュ → GitHub Issue更新 → 作業履歴 → status更新 → /compact）
- 「1セッション = 最大1SubTask」の原則（CLAUDE.md「自律実行の原則」参照）
- 品質ゲートは `.claude/hooks/pre-push-quality-gate.sh` で自動実行される
