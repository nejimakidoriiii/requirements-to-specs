# requirements-to-specs

自然言語の要求を、3つの形式仕様へ写像する OpenCode スキル。

| 形式 | 拡張子 | 答える問い |
|------|--------|-----------|
| [Gherkin](https://cucumber.io/docs/gherkin/reference/) | `.feature` | 利用者から何が観察できるか |
| [Quint](https://quint-lang.org/docs/lang) | `.qnt` | どの状態からどの状態へ遷移できるか |
| [Alloy](https://alloytools.org/spec.html) | `.als` | どの構造（エンティティと関係の組み合わせ）が存在してよいか |

3形式を同列に生成するのではなく、要求を分類して必要な形式だけに写像する。すべての生成物は REQ-ID で要求に紐付き、相互整合を trace matrix で確認する。

## パイプライン

`output_dir` は入力に応じて[出力先の規則](skills/requirements-to-specs/SKILL.md#出力先)で決める。

```text
1. 正規化   要求を原子化し REQ-ID を振る        → <output_dir>/requirements.md
2. 分類     REQ-ID ごとに3形式の要否を判定する    → <output_dir>/classification.yaml
3. 生成     分類表で true の形式だけ生成し、
            quint / alloy の検証を通す           → <output_dir>/{gherkin,quint,alloy}/
4. 整合性   trace matrix で矛盾を検出する        → <output_dir>/trace.md
```

分類表が生成の単一の真実の情報源。要求文から各形式へ直接生成すると意味がずれるため、生成は必ず分類表を経由する。

## 検証環境

Quint と Alloy の実行検証は Docker コンテナに閉じる。ホストの glibc や Java のバージョンに依存しない（quint の rust バックエンドは GLIBC_2.39、Apalache 同梱の z3 は GLIBC_2.34 と Java 21 を要求するため）。イメージの中身（`skills/requirements-to-specs/scripts/Dockerfile`）:

| 要素 | バージョン | 用途 |
|------|-----------|------|
| Ubuntu | 24.04（glibc 2.39） | ネイティブ依存の土台 |
| Node | 22.23.3 | quint の実行 |
| Temurin JRE | 21.0.12.1+1（SHA256 検証付き） | Apalache（quint verify） |
| quint | 0.33.0 | typecheck / run / verify |
| Alloy | 6.2.0 | commands / exec |

`scripts/verify.sh` がイメージのビルドと実行を代行する（初回はビルドに数分）。以下は要求文書を入力とした例:

```sh
scripts/verify.sh quint typecheck specs/quint/order.qnt
scripts/verify.sh quint run     specs/quint/order.qnt --invariant=noUnpaidShipment --max-steps=5
scripts/verify.sh quint verify  specs/quint/order.qnt --invariant=noUnpaidShipment --max-steps=1
scripts/verify.sh alloy commands specs/alloy/order.als
scripts/verify.sh alloy exec -f  specs/alloy/order.als
```

検証済みの動作: quint 0.33.0 の rust バックエンドと verify（Apalache 0.62.1）が上記の構成で動作する。

## インストール

リポジトリを clone し、`skills` ディレクトリをソースに追加する（`opencode.json` / `opencode.jsonc`）:

```jsonc
{
  "skills": [
    "/path/to/requirements-to-specs/skills"
  ]
}
```

または `~/.config/opencode/skills/` に `skills/requirements-to-specs` をコピーする。

## 使い方

ユーザー起動のスキル。スキル名を指定して呼び出す:

```text
requirements-to-specs を使って docs/requirement.md から仕様を生成して
```

対象の要求文書は既存の場所で読み取る。GitHub Issue も入力にでき、例えば Issue #123 の成果物は `specs/123/` に出力する。通常の要求文書の出力先は従来どおり `specs/`。

## リポジトリ構成

```text
skills/requirements-to-specs/
  SKILL.md                    # パイプライン本体
  references/
    gherkin.md                # .feature の規約（Gherkin を生成する分岐が読む）
    quint.md                  # .qnt の規約と検証（Quint を生成する分岐が読む）
    alloy.md                  # .als の規約と検証（Alloy を生成する分岐が読む）
    consistency.md            # 整合性確認の規約（ステップ4で読む）
  scripts/
    Dockerfile                # 検証コンテナ（quint 0.33.0 / Alloy 6.2.0 / Java 21）
    verify.sh                 # コンテナで quint / alloy を実行するラッパー
```
