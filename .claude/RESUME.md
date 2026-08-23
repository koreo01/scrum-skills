# /compact 後の復帰テンプレート

> このファイルは `/compact` 後に会話コンテキストを復元するためのテンプレート。
> 復帰時にこのファイルをそのまま使うのではなく、`.claude/status/current.md` を読んで状況を把握すること。

---

## 復帰手順

1. `.claude/status/current.md` を読む
2. 「次のアクション」セクションを確認し、そこから再開する
3. 必要に応じて関連ファイルを読んでコンテキストを補完する

---

## 復帰時の確認チェックリスト

- [ ] 現在のブランチを確認（`git branch --show-current`）
- [ ] 直近のコミットを確認（`git log --oneline -5`）
- [ ] `status/current.md` の「次のアクション」を確認

---

## よく参照するファイル

| ファイル | 用途 |
|---------|------|
| `.claude/status/current.md` | 現在の進捗・次のアクション |
| `CLAUDE.md` | ルール・規約（ブランチ名・コミット形式等） |
| `.claude/summaries/` | 完了済みSubTaskの作業履歴 |

---

## プロジェクト基本情報（クイックリファレンス）

- **リポジトリ**: scrum-skills（スクラム開発支援 Claude Code スキル集）
- **ブランチ形式**: `feat/{StoryID}_{英語サマリー}` / `chore/{TaskID}_{英語サマリー}`
- **コミット形式**: `[#{親ID}/#{SubTaskID}] {説明}`
