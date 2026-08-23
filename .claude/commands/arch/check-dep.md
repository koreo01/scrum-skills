# Arch Check Dependency Agent

`.dependency-rules.yml` に基づいてアーキテクチャ違反を検出します。

## コマンド形式

```
/arch:check-dep [options]
```

### オプション

| オプション | 説明 |
|-----------|------|
| `--fix` | 可能な場合、自動修正を提案 |
| `--ci` | CI用出力（exit code対応） |

### 使用例

```bash
# 違反チェック
/arch:check-dep

# CI/CDでの使用
/arch:check-dep --ci

# 修正提案付き
/arch:check-dep --fix
```

## 前提条件

`.dependency-rules.yml` が存在すること。存在しない場合は `/arch:init-dep` を先に実行してください。

## 処理フロー

### Step 1: ルールファイル読み込み

```yaml
# .dependency-rules.yml から読み込み
layers: [...]
rules:
  whitelist: [...]
  blacklist: [...]
```

### Step 2: import文の解析

各Goファイルのimport文を解析：

```go
// internal/usecase/booking.go
import (
    "github.com/project/internal/domain"  // ✅ 許可
    "github.com/project/internal/handler" // ❌ 違反
)
```

### Step 3: 違反検出

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 依存性チェック結果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 違反: 2件

### ❌ usecase → handler（逆依存）

ファイル: internal/usecase/booking.go:5
```go
import "github.com/project/internal/handler"
```

ルール: usecase層からhandler層への依存は禁止
理由: 上位層への逆依存禁止

📝 修正提案:
  - handler層の該当機能をinterface化してusecase層に移動
  - または依存方向を見直し

---

### ❌ domain → infra（ドメイン汚染）

ファイル: internal/domain/patient.go:8
```go
import "github.com/project/internal/infra/db"
```

ルール: domain層は他層に依存してはならない
理由: ドメイン層は他層に依存してはならない

📝 修正提案:
  - Repository interfaceをdomain層に定義
  - infra層でinterfaceを実装

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 サマリー
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
| レイヤー | ファイル数 | 違反数 |
|---------|-----------|--------|
| cmd | 2 | 0 |
| handler | 5 | 0 |
| usecase | 8 | 1 |
| domain | 12 | 1 |
| infra | 6 | 0 |
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
合計: 33ファイル / 2違反
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 4: 違反なしの場合

```
✅ 依存性チェック完了: 違反なし

チェック対象: 33ファイル
すべてのファイルがアーキテクチャルールに準拠しています。
```

## CI/CD統合

### GitHub Actions例

```yaml
# .github/workflows/architecture.yml
name: Architecture Check

on: [push, pull_request]

jobs:
  dep-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check Dependencies
        run: |
          # Claude Codeで実行
          claude "/arch:check-dep --ci"
```

### Exit Code

| Code | 意味 |
|------|------|
| 0 | 違反なし |
| 1 | 違反あり |
| 2 | ルールファイルなし |

## 関連コマンド

- `/arch:init-dep` - ルールファイル初期化
- `/arch:check-dep` - 違反チェック（このコマンド）
