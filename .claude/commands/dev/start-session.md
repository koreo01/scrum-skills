# /dev:start-session — 開発セッション開始チェック

CLAUDE.md「自律実行の原則」に基づき、開発セッションを安全に開始できる状態かを確認します。

---

## ワークフロー

以下のステップを順番に実行してください。

### Step 1: status/current.md の読み込み

`.claude/status/current.md` を読み込んで現在の作業状態を把握します。

- ファイルが存在しない → **ケースB**（チケット未整備）へ
- ファイルが存在する → Step 2 へ

### Step 2: 条件①チェック — Open な SubTask が存在するか

`status/current.md` のサブタスク進捗テーブルを確認します。

- 「⏳ 待機中」または「🔄 作業中」の SubTask が 1 件以上ある → 条件① OK、Step 3 へ
- 全件 ✅ Done または進捗テーブルが存在しない → **ケースB**（チケット未整備）へ

### Step 3: 条件②チェック — 同一Task/Storyブランチ上の継続作業か

現在のブランチが `status/current.md` の「現在のブランチ」と一致するかを確認します。

- **一致する場合** → 同一Task/Story内の継続作業（前SubTaskのコミットが積まれている状態は正常）→ 条件② OK、**正常スタート**へ
- **一致しない場合** → 以下のコマンドで未マージコミットを確認する:

```bash
git log origin/main..HEAD --oneline
```

  - 出力が空（未マージコミットなし）→ 条件② OK、**正常スタート**へ
  - 出力あり（未マージコミットあり）→ **ケースA**（マージ待ち）へ

---

## 判定結果と案内

### 正常スタート（条件① ② 両方 OK）

フェーズマーカーを STARTED に設定してから、状況を報告し、**報告後そのまま最初の SubTask の作業に着手する**（ユーザーの追加指示を待たない）：

```bash
echo "STARTED" > .claude/status/.session-phase
```

```
セッション開始チェック完了 — 作業を開始します。

現在のブランチ: {ブランチ名}
親Task: {Task ID・タイトル}

【引き継ぎ情報】
{引き継ぎ情報の内容}

次に着手するSubTask:
  {#xxx} {タイトル}

status/current.md の「次のアクション」:
{次のアクションの内容}
```

報告出力後、承認を待たずに上記 SubTask の作業を開始すること。

「引き継ぎ情報」セクションの表示ルール：
- `status/current.md` の「引き継ぎ情報」が「なし」または空の場合は、`【引き継ぎ情報】` ブロック全体を省略する
- 内容がある場合のみ表示する

### ケースA — 前ブランチのマージ待ち（セーフティネット）

> 通常は `/dev:end-session` で PR マージ・ブランチ削除まで完了するため、このケースは発生しない。
> 前セッションの end-session が中断された等の異常時のみ到達する。

未マージの PR が存在する場合は、end-session の残務として PR マージ・ブランチ削除を実行する:

```bash
# PR が存在するか確認
gh pr view --json number,state --jq '.number, .state'

# CI が通っていれば PR をマージしブランチを削除
gh pr merge --merge --delete-branch

# ローカルを main に切り替えて最新化し、作業ブランチを削除
git checkout main && git pull origin main && git branch -d {作業ブランチ名}
```

マージ完了後、Step 2 の条件①チェックから再開する。

PR が存在しない（push のみで PR 未作成）場合はユーザーに報告して停止する:

```
セッション開始を保留します。

未マージのコミットが検出されましたが、対応する PR が見つかりません：
{git log の出力}

前セッションの /dev:end-session が途中で中断された可能性があります。
対応方法を指示してください。
```

### ケースB — チケット未整備

```
セッション開始を保留します。

作業可能な SubTask が見つかりませんでした。

対応:
1. `gh issue list --label type:subtask` で次の Task/SubTask を確認してください
2. SubTask が存在する場合は status/current.md を更新してから
   再度 /dev:start-session を実行してください
3. SubTask が存在しない場合は、Task の SubTask を起票してください

SubTask 起票ルール（CLAUDE.md 参照）:
- `gh issue create --label type:subtask` で #xxx として起票
- 本文冒頭に Task の `Parent: #xxx` を記載
- 1SubTask = サブタスクのサイズ原則に従う（1つの検証可能な単位・1セッションで完結）
```

---

## 根拠

- 「1セッション = 最大1SubTask」の原則（CLAUDE.md「自律実行の原則」参照）
- CLAUDE.md「/compact 後の復帰手順」（status/current.md を読む）
