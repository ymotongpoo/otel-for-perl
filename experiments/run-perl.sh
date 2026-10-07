#!/bin/sh
# frontendと同じイメージで、experiments/のPerlスクリプトを実行する
exec docker run --rm --network yapc-perl-otel_default -v "$(cd "$(dirname "$0")" && pwd)":/e -w /e "$@"
