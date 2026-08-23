# Claude 作業フロー（全ステップ手順書）

CLAUDE.mdの原則に対応する具体的な手順書。
セッション起動からSubTask完了チェックリストまでの全フローを記述する。

> **セッションの粒度：1セッション = 最大1SubTask。**
> 1SubTaskのコミット・完了チェックリストを終えたら `/compact` を案内し、次のSubTaskは新セッションで着手する。

---

## ① セッション起動・状態確認（`/dev:start-session` 一括実行）

新セッション開始時、または `/compact` 後の復帰時に `/dev:start-session` を実行する。本コマンドが以下を承認なしで一括実行する（詳細は `.claude/commands/dev/start-session.md` 参照）。

1. **`status/current.md` 読み込み**（現在のブランチ・親 Task・サブタスク進捗・次のアクションを把握）
2. **条件①チェック**（Open な SubTask が 1 件以上あるか）
3. **条件②チェック**（同一 Task ブランチ上の継続作業 / 未マージコミットなし）
4. **ケース判定**（正常スタート / ケースA: マージ待ち / ケースB: チケット未整備）
5. **フェーズマーカー更新**（`.claude/status/.session-phase` → `STARTED`）
6. **正常スタート時はそのまま次の SubTask 着手を報告**（ユーザー承認なし）

判定結果に応じて以降 ②〜④ の挙動が変わる。

---

## ② 担当 SubTask の確認

`/dev:start-session` の判定結果ごとに分岐する。

| 判定 | 対応 |
| --- | --- |
| **正常スタート** | コマンド出力が「次に着手する SubTask（#xxx）」と「引き継ぎ情報」を提示するため、その内容に沿って作業を開始する。GitHub Issues を手動参照する必要はない |
| **ケースB（チケット未整備）** | コマンドが停止する。`gh issue list` で次の Task/SubTask を確認し、未起票なら起票（Issue → Task → SubTask の順、`gh issue create --label type:subtask`）、`status/current.md` を更新してから再度 `/dev:start-session` を実行する |
| **ケースA（前ブランチのマージ待ち）** | 通常は発生しない（`/dev:end-session` が PR マージまで完了させるため）。発生時はコマンドが残務（PR マージ・ブランチ削除）を自動実行するか、PR 未作成ならユーザーに報告して停止する |

> 詳細な SubTask 内容・完了基準は GitHub Issue 本文（`gh issue view #xxx`）を参照する。`status/current.md` 「次のアクション」にも要点は転記されているが、原典は GitHub Issue。

---

## ③ origin/main の最新化確認（`/dev:start-session` 条件②で自動）

`/dev:start-session` Step 3 が条件②として以下を自動チェックする。

- 現在のブランチが `status/current.md` の「現在のブランチ」と一致 → 同一 Task 継続作業として正常スタート
- 一致しない場合は `git log origin/main..HEAD` で未マージコミットを確認し、未マージコミットがあれば**ケースA**として停止

手動で `git fetch origin` / `git log origin/main` を叩く必要はない。

> ℹ️ **手動チェック手順は `.claude/rules/branch-checklist.md` Step 1 に参照用として残してある**（`/dev:start-session` を経由しない異常時や、自動判定が想定外の状態を検出した場合に使う）。

---

## ④ ブランチ作成（`/dev:start-session` ケースA で自動）

`/dev:start-session` が「正常スタート」と判定し、まだ作業ブランチが存在しない場合（新 Task 着手時）はコマンドが `chore/{TaskID}_{英語サマリー}` 形式（`.claude/config/ticket-system.json` の `branchNaming.formats.chore` 参照）のブランチを main から自動作成する。同一 Task 継続作業（前 SubTask のコミットが積まれている）の場合は既存ブランチをそのまま使う。

> ⚠️ **Pre-ToolUse フック `.claude/hooks/pre-bash-branch-source-check.sh` により、main 以外からの `git checkout -b` は自動ブロックされる**（GitHubFlow 違反の防止）。Claude が手動で `git checkout -b` を実行することはなく、`/dev:start-session` 経由でのみブランチを作成する。

> ℹ️ **手動チェック手順は `.claude/rules/branch-checklist.md` Step 2〜3 に参照用として残してある**（`/dev:start-session` を経由せずブランチを切る必要が生じた場合の手順）。

---

## ⑤〜⑦ 作業実施ループ（SubTask 単位）

**SubTask 1件ずつ ⑤→⑥→⑦ を繰り返す。複数SubTaskをまとめて処理しない。**

### ⑤ 実装・編集

担当SubTaskの作業内容を実施する。1SubTaskの実装が完了したら ⑥ へ進む。

#### コンテキスト大規模消費時の対応（1SubTask複数セッション）

大規模リファクタリング等で SubTask 完了前に `/compact` が必要になる場合。

**事前に作業量が大きいと分かっている場合：**
- 着手前に意図・設計判断を `status/current.md` の「次のアクション」に詳細記録してから作業開始
- コミット前でも `save-summary` スキルで意思決定を記録できる

**作業途中で `/compact` が発生した場合（SubTask 未完了）：**
1. `/compact` 前に `status/current.md` を更新（どこまで進んだか・次に何をするかを詳細に記録）
2. 次セッションは `/dev:start-session` から再開し、**同じ SubTask の続き**として作業継続（ブランチ作成はスキップ）
3. SubTask 完了後に通常どおり ⑥（コミット）→ ⑦（`/dev:end-session`）を実施

### ⑥ コミット前確認 → コミット

#### ⑥-1. 変更内容をユーザーに確認（承認必須）

実装完了後、コミットの前に変更サマリーをユーザーに提示し承認を得る。

```text
変更内容を確認してください。
- 変更ファイル: {ファイル名一覧}
- 変更の要点:
  - {変更点1}
  - {変更点2}
コミットしてよいですか？
```

承認を得てから ⑥-2 へ進む。**承認なしでコミットしない。**

#### ⑥-2. コミット

```bash
git add {変更ファイル}  # 必要なファイルのみ指定
git commit -m "[#{親TaskID}/#{SubTaskID}] 説明"
```

> ℹ️ コミットメッセージのフォーマット実値は `.claude/config/ticket-system.json` の `commitMessage.formats` 参照。
> ⚠️ **Pre-ToolUseフックにより、#xxx なしのコミットは自動ブロックされる。**

コミット完了後は ⑦ `/dev:end-session` を実行する。**省略・後回し・例外なし。**

### ⑦ 完了チェックリスト（`/dev:end-session` 一括実行）

コミット完了後、`/dev:end-session` を実行する。本コマンドが Step 0 で「途中 SubTask 完了」「最終 SubTask 完了」を自動判定し、以下を承認なしで一括実行する（詳細は `.claude/commands/dev/end-session.md` 参照）。

1. **git push**（pre-push 品質ゲート Hook が自動実行）
2. **CI 結果確認**（失敗時は自動修正・再 push、最大 2 回リトライ）
3. **PR 作成・マージ・ブランチ削除**（**最終 SubTask 完了時のみ**。途中 SubTask ではスキップ）
4. **GitHub Issue 更新**（`gh issue close` で SubTask を Close、完了日時を JST で `gh issue comment` に記録）
5. **作業履歴 MD 出力**（`.claude/summaries/YYYY-MM-DD_{チケット番号}_{説明}.md` ／ `save-summary` スキル）
6. **`status/current.md` 更新**（完了 SubTask を ✅、引き継ぎ情報・次のアクションを更新）
7. **フェーズマーカー更新**（`.claude/status/.session-phase` → `POST_PROCESSED`）
8. **`/compact` の実行を案内**

エラー発生時のみ停止してユーザーに報告する。それ以外はユーザー承認なしで一括実行される。

---

## ⑧ PR 作成・マージ（最終 SubTask 時のみ自動）

Task 内の最終 SubTask 完了時、⑦の `/dev:end-session` が Step 3 で以下を自動実行する。

1. `gh pr create` で PR 作成
2. CI 通過確認後 `gh pr merge --merge --delete-branch` で main にマージ
3. ローカルを main に切り替え、作業ブランチを削除

途中 SubTask 完了時は PR 作成はスキップされ、push のみが実行される。最終 / 途中の判別は `/dev:end-session` Step 0 が自動で行う。

> Claude が手動で `gh pr create` / `gh pr merge` を実行することはない（`/dev:end-session` 経由でのみ実行する）。

---

## NG パターン

```text
# ❌ コミット後に /dev:end-session を省略して次の SubTask に着手
#{SubTask1}コミット → 直接 #{SubTask2} 着手（⑦未実施）

# ✅ コミットごとに /dev:end-session を実行（正しい）
#{SubTask1}コミット → /dev:end-session（Step 1-8 一括）→ /compact 案内
（新セッション）/dev:start-session → #{SubTask2} 着手
```

```text
# ❌ 複数 SubTask 分をまとめて /dev:end-session
#{SubTask1}コミット → #{SubTask2}コミット → まとめて /dev:end-session

# ✅ SubTask 単位で /dev:end-session を実行
#{SubTask1}コミット → /dev:end-session
（新セッション）#{SubTask2}コミット → /dev:end-session
```

```text
# ❌ コミット前に /dev:end-session
（未コミット状態）/dev:end-session → 対象コミットがなく動作しない

# ✅ コミット後に /dev:end-session
git commit -m "[#xxx/#yyy] ..." → /dev:end-session
```
