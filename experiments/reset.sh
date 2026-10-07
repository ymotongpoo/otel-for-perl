#!/bin/sh
# Collectorの出力を空にして、frontendを指定のコマンドで起動し直す。
# 使い方: FRONTEND_CMD="..." experiments/reset.sh
set -e
cd "$(dirname "$0")/.."
docker compose stop frontend collector >/dev/null 2>&1 || true
rm -f out/otlp.jsonl
docker compose up -d --build frontend >/dev/null 2>&1
for i in $(seq 1 30); do curl -s -o /dev/null "http://localhost:5000/report?days=1" && break; sleep 1; done
sleep 6   # 起動確認の1リクエスト分が他の計測に混ざらないよう、Collectorの書き出しを待つ
rm -f out/otlp.jsonl
docker compose restart collector >/dev/null 2>&1
sleep 3
