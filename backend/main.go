// ratesは為替レートを返す下流サービス。Perlのフロントエンドから呼ばれる。
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
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
	defer tp.Shutdown(ctx)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /rates", rates)
	log.Fatal(http.ListenAndServe(":8080", otelhttp.NewHandler(mux, "rates")))
}
