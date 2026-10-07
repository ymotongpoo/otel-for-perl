# otel-for-perl

PerlのPSGIアプリケーションを、CPANのOpenTelemetry実装と、OpenTelemetry eBPF Instrumentation（OBI）の両方で観測するデモです。
Zenn本『OpenTelemetryのPerl実装にいまこそ必要なもの』（YAPC::Tokyo 2026の登壇の解説資料、2026年11月28日公開予定）の数値は、この構成で測りました。

## 構成

集計結果を返すPerlのサービス `report` が、為替レートを返すGoのサービス `rates` をHTTPで呼びます。
テレメトリーはOpenTelemetry Collectorが受け取り、`out/otlp.jsonl` に保存しながらGrafanaのスタックへ転送します。

| サービス | 中身 |
| --- | --- |
| `frontend` | Perl 5.44.0のPSGIアプリケーション `report`。起動するコマンドは環境変数 `FRONTEND_CMD` で差し替える |
| `backend` | Goの `rates`。公式のOpenTelemetry Go SDKと `otelhttp` |
| `collector` | otel/opentelemetry-collector-contrib 0.162.0。受け取ったOTLPを `out/otlp.jsonl` に保存し、`lgtm` へ転送する |
| `lgtm` | grafana/otel-lgtm 0.32.1。Grafanaはホストの3300番 |
| `obi` | otel/ebpf-instrument v0.14.0。`--profile obi` を付けたときだけ起動する |

遅さの原因は2か所に仕込んであります。
集計処理は1日分あたり3ミリ秒眠り、`rates` はUSD、EUR、JPY以外の通貨で600ミリ秒かけて応答します。

```sh
curl 'http://localhost:5000/report?days=7&currency=USD'    # 速い
curl 'http://localhost:5000/report?days=180&currency=USD'  # 集計が遅い
curl 'http://localhost:5000/report?days=7&currency=BRL'    # ratesが遅い
```

## PSGIファイルと本の章

| ファイル | 内容 | 本の章 |
| --- | --- | --- |
| `frontend/app.psgi` | 計装していない版 | 2章、9章 |
| `frontend/app_otel.psgi` | CPANの実装を組み込んだ版。SDKのデフォルトのBatchプロセッサーを使う | 5章、8章 |
| `frontend/app_otel_simple.psgi` | `app_otel.psgi` をSimpleプロセッサーで動かす | 4章、5章、6章、8章 |
| `frontend/app_otel_pump.psgi` | `app_otel.psgi` を `Demo::OTelPump` で包む回避策。`PUMP_INTERVAL` 秒ごとに `force_flush` し、`SHUTDOWN_HOOK=1` で終了時にも `force_flush` する | 8章 |
| `frontend/app_async.psgi` | Twiggy向けの非同期版。計装していない | 9章 |
| `logs/` | SDKを0.029-TRIALにした別の依存一式と、ログを送るスクリプト | 7章 |

## 動かし方

DockerとDocker Composeが必要です。
OBIを使う場合は、BTFのあるLinux（カーネル5.8以降）で、特権コンテナを動かせる必要があります。

```sh
mkdir -p out && chmod 777 out   # CollectorはUID 10001で書き込む
docker compose up -d --build
```

起動するPSGIファイルとサーバーは `FRONTEND_CMD` で選びます。
`experiments/reset.sh` はCollectorの出力を空にしてから `frontend` を起動し直します。

```sh
FRONTEND_CMD="plackup -E deployment -s HTTP::Server::PSGI -p 5000 app_otel_simple.psgi" experiments/reset.sh
experiments/load.sh 100 8 "days=20&currency=USD"     # 100回、8並列
python3 experiments/count_spans.py out/otlp.jsonl     # サービスごとのスパン数
python3 experiments/check_traces.py out/otlp.jsonl    # SDKのトレースの親子がそろっているか
python3 experiments/trace_tree.py out/otlp.jsonl report.days   # トレースの木
```

Starmanを使うなら、`FRONTEND_CMD="plackup -E deployment -s Starman --workers 4 -p 5000 app_otel_simple.psgi"` のように渡します。
`--preload-app` は `--preload-app=1` と書いてください。
plackupは知らないオプションの次の引数をそのオプションの値として扱うので、`--preload-app app_otel.psgi` の順だとPSGIファイルの指定が消え、カレントディレクトリの `app.psgi` が起動します。

### OBI

```sh
FRONTEND_CMD="plackup -E deployment -s Starman --workers 4 -p 5000 app.psgi" experiments/reset.sh
docker compose --profile obi up -d obi
experiments/load.sh 100 8 "days=20&currency=USD"
python3 experiments/check_obi.py out/otlp.jsonl       # OBIのトレースの親子と、ratesへの伝搬
```

`compose.yaml` の `obi` は `/sys/kernel/tracing` と `/sys/fs/cgroup` をマウントしています。
カーネルの不具合（commit 929e30f93125）の影響を受けるカーネルでは、tracefsが無いとOBIは文脈の伝搬を自動で止めます。
cgroupが見えないと、OBIの起動後に張られた接続に `traceparent` が書き込まれません。

### ログ（SDK 0.029-TRIAL）

```sh
docker run --rm -v "$PWD/logs":/app -w /app perl:5.44.0 sh -c 'cpanm -nq Carton@1.0.35 && carton install'
docker run --rm --network yapc-perl-otel_default -v "$PWD/logs":/l -w /l \
  -e PERL5LIB=/l/local/lib/perl5 -e OTEL_SERVICE_NAME=e5-logs \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318 perl:5.44.0 perl e5_logs.pl
```

### 単体のスクリプト

`experiments/run-perl.sh` は、`frontend` と同じイメージで `experiments/` のスクリプトを動かします。

```sh
experiments/run-perl.sh yapc-perl-otel-frontend perl e2_api_only.pl      # APIだけでは何も記録されない
experiments/run-perl.sh -e OTEL_TRACES_EXPORTER=console yapc-perl-otel-frontend perl e2_sdk.pl
experiments/run-perl.sh -e OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318 yapc-perl-otel-frontend perl e6_shutdown.pl         # shutdownだけでは送られない
experiments/run-perl.sh -e OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4318 yapc-perl-otel-frontend perl e6_shutdown.pl flush   # force_flushの後なら届く
```

## 検証環境

2026年10月7日に、Linux 7.0.0（x86_64）とDocker 29.0.0で確かめました。

- Perl 5.44.0（`perl:5.44.0`）、Carton 1.0.35
- OpenTelemetry 0.039、OpenTelemetry::SDK 0.028（ログだけ0.029-TRIAL）、OpenTelemetry::Exporter::OTLP 0.021、Plack::Middleware::OpenTelemetry 0.262410。推移的な依存は `frontend/cpanfile.snapshot` と `logs/cpanfile.snapshot` に固定してある
- Go 1.27.1、OpenTelemetry Go v1.47.0、otelhttp v0.72.0
- OBI v0.14.0
