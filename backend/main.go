// ratesは為替レートを返す下流サービス。Perlのフロントエンドから呼ばれる。
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// キャッシュにある通貨は速く、無い通貨は上流への問い合わせを模して遅く返す。
var cached = map[string]float64{"USD": 1, "EUR": 0.92, "JPY": 151.3}

func rates(w http.ResponseWriter, r *http.Request) {
	cur := r.URL.Query().Get("currency")
	rate, ok := cached[cur]
	if ok {
		time.Sleep(20 * time.Millisecond)
	} else {
		time.Sleep(600 * time.Millisecond)
		rate = 5.4
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"currency": cur, "rate": rate, "cached": ok})
}

func main() {
	// SIGTERMとCtrl-Cで終了処理に入る
	sigCtx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	ctx := context.Background()
	exp, err := otlptracehttp.New(ctx) // OTEL_EXPORTER_OTLP_ENDPOINTを読む
	if err != nil {
		log.Fatal(err)
	}
	res, err := resource.New(ctx, resource.WithFromEnv(), resource.WithTelemetrySDK())
	if err != nil {
		log.Fatal(err)
	}
	tp := sdktrace.NewTracerProvider(sdktrace.WithBatcher(exp), sdktrace.WithResource(res))
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /rates", rates)
	srv := &http.Server{Addr: ":8080", Handler: otelhttp.NewHandler(mux, "rates")}
	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	<-sigCtx.Done()

	// 取り消し済みのsigCtxではなく、上限付きの新しいコンテキストで後片付けする
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil { // 処理中のリクエストを待つ
		log.Print(err)
	}
	if err := tp.Shutdown(shutdownCtx); err != nil { // キューに残ったスパンを送る
		log.Print(err)
	}
}
