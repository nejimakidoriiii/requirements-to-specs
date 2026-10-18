---
name: requirements-to-specs
description: 要求一覧を Gherkin / Quint / Alloy の形式仕様へ分類・生成し、REQ-ID で相互整合を確認する
disable-model-invocation: true
---

自然言語の要求を、3つの形式仕様へ写像する。3形式は同じ要求の言い換えではなく、それぞれ別の問いに答える:

| 形式 | 拡張子 | 答える問い |
|------|--------|-----------|
| Gherkin | `.feature` | 利用者から何が観察できるか |
| Quint | `.qnt` | どの状態からどの状態へ遷移できるか |
| Alloy | `.als` | どの構造（エンティティと関係の組み合わせ）が存在してよいか |

REQ-ID を通貨として、3形式が同じ要求を検査していることを保証する。状態名・エンティティ名は requirements.md の語彙から取り、3形式で同一の綴りを使う。

## パイプライン

### 1. 正規化 — `specs/requirements.md`

要求文書を読み、要求を原子化する:

1. 要求を1件ずつ切り出す。1件 = 動作または制約を1つだけ含む文。複数の動作が1文に混ざっていたら分割して別REQ-IDを振る
2. 曖昧語（「など」「適切に」「必要に応じて」「場合により」）を排除する。排除できなかった要求は requirements.md の「未解決」セクションに移し、原文と確認事項を並記する
3. `REQ-001` から順に連番を振る

完了: 元文書のすべての要求が requirements.md で (a) REQ-ID 付き、(b) 動作か制約を1つだけ含む文、(c) 曖昧語なし、を満たす。未解決の要求があれば生成対象から外し、パイプラインの最後にユーザーへ報告する。

### 2. 分類 — `specs/classification.yaml`

各 REQ-ID について3形式の要否を判定し、分類表に書く:

```yaml
REQ-001:
  text: 支払い前の注文は発送できない
  gherkin: true  # 利用者が発送の拒否を観察する
  quint: true    # unpaid 状態で ship が実行不可
  alloy: false   # 構造制約ではなく状態遷移で表現できる
```

判定は3つの問いで行う:

| 問い | true になる要求の例 |
|------|--------------------|
| 利用者または外部システムが入力を与え、応答を受け取るか（Gherkin） | 画面表示、API の応答、エラーメッセージ |
| システム内部に変化する状態と、常に守るべき条件があるか（Quint） | ステータス遷移、残高・個数の下限、排他制御 |
| エンティティ間の関係で、存在してよい組み合わせを制限するか（Alloy） | 所有関係、1対多、循環参照の禁止 |

1つの REQ-ID で複数 true になってよい。3つとも false になる要求は requirements.md の記述漏れか範囲外なので、次のステップに進む前にユーザーに確認する。

完了: すべての REQ-ID に3列の true/false が入り、false のすべてに根拠コメントが付いている。分類表はこのあとの生成の唯一の入力になる。要求文から各形式へ直接生成すると意味がずれるため、生成は必ず分類表を経由する。

### 3. 生成

分類表で true になった形式だけを生成する。生成の入力は requirements.md の該当 REQ-ID と classification.yaml に限る。生成前にその形式の規約ファイルを読む:

- Gherkin → `references/gherkin.md` → `specs/gherkin/*.feature`
- Quint → `references/quint.md` → `specs/quint/*.qnt`
- Alloy → `references/alloy.md` → `specs/alloy/*.als`

同じドメインの REQ-ID は1ファイルにまとめる（1要求1ファイルにしない）。

Quint と Alloy の生成物は `scripts/verify.sh`（Docker が必要）で検証を通す。検査が通らない生成物は次のステップに進む前に直す。Gherkin は実行処理系がステップ定義（実装）に依存するため検証対象外とし、規約ファイルの様式に従う:

```sh
scripts/verify.sh quint typecheck specs/quint/order.qnt
scripts/verify.sh quint run     specs/quint/order.qnt --invariant=<定義名> --max-steps=5
scripts/verify.sh quint verify  specs/quint/order.qnt --invariant=<定義名> --max-steps=1
scripts/verify.sh alloy commands specs/alloy/order.als
scripts/verify.sh alloy exec -f  specs/alloy/order.als
```

完了: 分類表の true セルすべてに対応する定義が生成物にあり、REQ-ID が各形式の規約ファイルが定める位置に埋め込まれている。Quint の生成物は typecheck / run / verify を、Alloy の生成物は commands / exec を通っている。

### 4. 整合性確認 — `specs/trace.md`

`references/consistency.md` を読み、trace matrix を作成して同一 REQ-ID の生成物を突き合わせる。矛盾を見つけたら生成物を黙って直して隠さない。矛盾は要求側の曖昧さの兆候なので、trace.md に記録しユーザーに報告する。

完了: 分類表に true がある REQ-ID × 形式のすべての組について、consistency.md の確認項目を判定し、結果を trace matrix として trace.md に残している。矛盾と未解決の要求をすべて報告済み。

## 出力構造

```text
specs/
  requirements.md       # REQ-ID 付き要求一覧（ステップ1）
  classification.yaml   # 分類表（ステップ2。生成の単一の真実の情報源）
  trace.md              # trace matrix（ステップ4）
  gherkin/*.feature
  quint/*.qnt
  alloy/*.als
```

`specs/` が既に存在するときはその構造に従い、requirements.md / classification.yaml / trace.md の3点セットは `specs/` 直下に置く。
