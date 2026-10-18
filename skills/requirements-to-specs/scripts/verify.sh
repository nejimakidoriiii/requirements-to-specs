#!/usr/bin/env bash
# quint / Alloy を検証コンテナで実行する薄いラッパー。
# イメージは初回実行時にビルドする。コマンドは素通しし、オプションは quint / Alloy に渡す。
#
# 使い方（ワークスペースのルートで実行する。$PWD を /work にマウントする）:
#   verify.sh quint typecheck specs/quint/order.qnt
#   verify.sh quint run specs/quint/order.qnt --invariant=noUnpaidShipment --max-steps=5
#   verify.sh quint verify specs/quint/order.qnt --invariant=noUnpaidShipment --max-steps=1
#   verify.sh alloy commands specs/alloy/order.als
#   verify.sh alloy exec -f specs/alloy/order.als
set -euo pipefail

tool="${1:?usage: verify.sh quint|alloy <subcommand> [args...]}"
shift
script_dir="$(cd "$(dirname "$0")" && pwd)"
image="requirements-to-specs-verify"

docker build -q -t "$image" "$script_dir" >/dev/null

case "$tool" in
  quint)
    exec docker run --rm -v "$PWD:/work" -w /work "$image" quint "$@"
    ;;
  alloy)
    exec docker run --rm -v "$PWD:/work" -w /work "$image" java -jar /opt/alloy/alloy.jar "$@"
    ;;
  *)
    echo "unknown tool: $tool (expected quint or alloy)" >&2
    exit 2
    ;;
esac
