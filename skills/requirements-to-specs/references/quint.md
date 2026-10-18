# Quint — `<output_dir>/quint/*.qnt`

Quint は「どの状態からどの状態へ遷移できるか」と「すべての到達可能状態で常に守る条件（invariant）」を書く。システム内部の状態遷移と安全条件が対象。

## REQ-ID の埋め込み

定義の直前にコメントで書く。invariant と action のどちらがその要求を担うかで、REQ-ID を付ける定義を選ぶ:

```quint
// REQ-001: 支払い前の注文は発送できない
action ship(id: str): bool = all {
  paid.get(id),
  not(shipped.get(id)),
  shipped' = shipped.set(id, true),
  paid' = paid,
}

/// REQ-001: 発送済みなら支払い済み（invariant としての側面）
val noUnpaidShipment = orders.forall(id =>
  shipped.get(id) implies paid.get(id))
```

## 骨格

```quint
module order {
  pure val orders: Set[str] = Set("o1", "o2")

  var paid: str -> bool
  var shipped: str -> bool

  action init = all {
    paid' = orders.mapBy(_ => false),
    shipped' = orders.mapBy(_ => false),
  }

  action pay(id: str): bool = all {
    not(paid.get(id)),
    paid' = paid.set(id, true),
    shipped' = shipped,
  }

  // REQ-001: 支払い前の注文は発送できない
  action ship(id: str): bool = all {
    paid.get(id),
    not(shipped.get(id)),
    shipped' = shipped.set(id, true),
    paid' = paid,
  }

  action step = {
    nondet id = orders.oneOf()
    any {
      pay(id),
      ship(id),
    }
  }

  /// REQ-001: 発送済みなら支払い済み（ship のガードが正しければ常に成り立つ）
  val noUnpaidShipment = orders.forall(id =>
    shipped.get(id) implies paid.get(id))
}
```

- ファイル名はモジュール名と一致させる（`module order` → `order.qnt`）
- `quint run` / `quint verify` は `init` と `step` をデフォルトの起点として使う
- invariant は `val`（bool を返す状態述語）として定義し、`quint verify order.qnt --invariant=noUnpaidShipment` で確認する。複数は `--invariants inv1 inv2`

## 規約

- 状態変数は要求を表現する最小限にする。実装の詳細（タイムスタンプ、連番）は要求が触れない限り置かない
- 列挙する状態（未払い・支払い済み・発送済みのように排他的なステータス）は sum type（`type Status = Unpaid | Paid | Shipped`）で表現できる。状態の追加・廃止が要求から出てきたら型定義に反映する
- action のガード（実行条件）を `all { ... }` の先頭に並べ、その後に代入を書く。ガードを満たさない action は実行不可、という形で「実行できない要求」を表現する
- 引数に型注釈を書く action は戻り値型（`: bool`）も書く。quint 0.32 のパーサーは引数だけの注釈を許さない
- 変数に代入を書かない action では、その変数は次状態で任意の値を取りうる。変化させない変数には `x' = x` を明示する
- 要求の種類と書き分け: 状態遷移は action、常に守る条件は val による invariant。「必ず〜が起こる」（liveness）の要求だけ `temporal`（`always` / `eventually`）を使う。まず invariant で書けないか検討する
- 複数のアクションが候補になる遷移は `action step = any { ... }` に列挙する。操作対象など非決定的な選択は、step の先頭で `nondet x = S.oneOf()` と束縛してから列挙の中で使う

## Gherkin との対応

Gherkin の Given は状態変数の値、When は action 名、Then は action のガードによる許可・拒否と次状態の値に対応する。Given/When に使う語彙は変数の値と action の名前にそのまま現れるようにする。整合性確認（`consistency.md`）でこの対応を検査する。

## 検証

生成した .qnt は、typecheck（型検査）→ run（シミュレーション）→ verify（形式検証）の順に通す。処理系はホストにインストールせず、`scripts/verify.sh` が検証コンテナ（quint 0.33.0 / Java 21 同梱、Docker が必要）で実行する。ワークスペースのルートから:

```sh
scripts/verify.sh quint typecheck "$output_dir/quint/order.qnt"
scripts/verify.sh quint run     "$output_dir/quint/order.qnt" --invariant=noUnpaidShipment --max-steps=5
scripts/verify.sh quint verify  "$output_dir/quint/order.qnt" --invariant=noUnpaidShipment --max-steps=1
```

- 初回実行はイメージのビルドに数分かかる
- 3検査の意味: typecheck は定義の型整合、run はランダム実行での invariant 違反の探索、verify は到達可能な全状態での反例探索
- verify は `--max-steps=1` を既定にする。単調なモデル（一度 paid や shipped になった状態が戻らない等）は遷移が尽きた時点で deadlock 検出に掛かるため。状態が戻る遷移があるモデルでは max-steps を増やすほど深く検証できる
- invariant はモデルごとに `--invariant=<定義名>` で指定する。複数チェックするときは `--invariants=名前1,名前2`
