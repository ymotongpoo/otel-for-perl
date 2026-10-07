#!/bin/sh
# /reportへN回リクエストする。並列数はCで指定する（既定は1）。
N=${1:-10}; C=${2:-1}; Q=${3:-days=7&currency=USD}
seq 1 "$N" | xargs -P "$C" -I{} curl -s -o /dev/null -w '%{http_code} %{time_total}\n' "http://localhost:5000/report?$Q"
