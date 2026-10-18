# Alloy — `<output_dir>/alloy/*.als`

Alloy は「どの構造が存在してよいか」を書く。エンティティ（sig）と関係（field）の組み合わせのうち、存在してよいものを制約する。静的な構造制約が対象。状態遷移は Quint の領分であり、Alloy 6 の `var` や時制演算子（`always` / `eventually`）は、要求が静的構造では表せないときの最終手段とする。

## REQ-ID の埋め込み

fact と assert の名前に含めるか、直前にコメントで書く:

```alloy
// REQ-002: 1つの注文には必ず1人の所有者がいる
fact REQ002_OneOwnerPerOrder {
  all o: Order | one o.owner
}

// REQ-002: 所有者のいない注文は存在しない
assert REQ002_NoOrphanOrder {
  all o: Order | some o.owner
}
check REQ002_NoOrphanOrder
```

## 骨格

```alloy
module order

sig User {}
sig Payment {}

sig Order {
  owner:   one User,       // REQ-002: 全注文が所有者を1人持つ
  payment: lone Payment    // 未払いの注文は支払いを持たない
}

// 発送済みの注文（Order の部分集合）
sig ShippedOrder in Order {}

// REQ-001（静的側面）: 発送済みの注文は支払いを持つ
fact REQ001_ShippedNeedsPayment {
  all o: ShippedOrder | some o.payment
}

// REQ-002: 所有者のいない注文は存在しない
// （owner: one User の宣言多重度で既に保証されるが、
//  fact を追加しても宣言の意図が壊れていないことを確認できる）
assert REQ002_NoOrphanOrder {
  all o: Order | some o.owner
}
check REQ002_NoOrphanOrder for 3
```

- ファイル名はモジュール名と一致させる（`module order` → `order.als`）

## 多重度 — 構造制約の主な道具

| 宣言 | 意味 |
|------|------|
| `lone` | 0か1 |
| `one` | ちょうど1 |
| `some` | 1以上 |
| `set` | 任意（個数制約なし） |
| `r: A -> one B` | A から B への全関数 |
| `r: A -> lone B` | A から B への偏関数 |
| `r: A some -> B` | B の要素は必ず r に現れる |

「1人のユーザーは複数の注文を持てる」「1つの注文には必ず1人の所有者がいる」のような要求は、多重度の宣言だけで書けることが多い。

## 規約

- 構造の前提（常に成り立つべき制約）は `fact`、事実から従うべき帰結の検証は `assert` + `check` に書く。要求が「〜してはならない」なら、その否定を許さない fact として書く
- 循環参照の禁止は推移閉包で書く: `all o: Order | o not in o.^parent`
- `pred` + `run` で空の制約を run すると、fact 群が無矛盾か（満たせる例が存在するか）を確認できる。fact を書き足すたびに矛盾で空にならないか確認する
- `check` / `run` にはスコープを付ける（`check NoOrphanOrder for 3`）。探索はスコープ内で完結するため、反例が見つからなくてもスコープ外に反例が残る可能性はある
- 個数の上限・下限（「注文は最大5件まで」）は Alloy のスコープではなく fact で表現する（`#o.items <= 5`）

## Quint との対応

状態遷移を持つ制約（「支払いの後でのみ発送」）は Quint の action と invariant で表現する。Alloy に書くのは、遷移の前後を問わず常に成り立つ構造関係（所有、多重度、循環禁止）に限る。同じ REQ-ID が両方に現れるときは、Alloy の fact が静的側面、Quint の action/invariant が動的側面を担う。

## 検証

生成した .als は、commands（構文とコマンドの確認）→ exec（全コマンド実行）の順に通す。処理系はホストにインストールせず、`scripts/verify.sh` が検証コンテナ（Alloy 6.2.0 同梱、Docker が必要）で実行する。ワークスペースのルートから:

```sh
scripts/verify.sh alloy commands "$output_dir/alloy/order.als"
scripts/verify.sh alloy exec -f "$output_dir/alloy/order.als"
```

- `exec` の結果は実行時のカレントディレクトリ（通常はワークスペースのルート）に `<ファイル名>/` ディレクトリ（receipt.json と解）として出力される。`-f` は既存ディレクトリの上書きで、2回目以降の実行に必要
- `check` の結果 `UNSAT` は反例なし（assertion がスコープ内で成立）。`SAT` は反例が見つかっている
- `java -jar alloy.jar` を直接実行する場合、サブコマンドなしで起動すると GUI が立ち上がる。CLI では必ずサブコマンドを付ける
