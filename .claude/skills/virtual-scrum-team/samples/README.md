# samples フォルダについて

このフォルダは**テスト用のサンプル議事録**を配置する場所です。

## 本番運用時

実際の議事録は以下のフローで処理されます：

```
Google Meets → ~/Downloads/meet-transcripts/ → import-transcripts.sh
→ analysis/transcripts/cleaned/daily/YYYY-MM-DD/
```

## テスト用サンプルが必要な場合

以下の形式でサンプルを作成してください：

```
samples/
├── daily-sample.txt       # Daily Scrum のサンプル
├── retro-sample.txt       # Retrospective のサンプル
└── planning-sample.txt    # Sprint Planning のサンプル
```

## サンプル作成のポイント

SM Core Agent のテストには、以下のような**意図的な問題点**を含めると効果的です：

- タイムボックス超過
- 報告会形式への固定化
- スプリントゴールへの言及不足
- 沈黙メンバーの存在
- 障害の未解決放置
- 個人攻撃的な発言
- 抽象的な改善案

これらを検出できるかどうかで、Agent の性能を評価できます。
