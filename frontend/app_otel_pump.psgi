# app_otel.psgiをDemo::OTelPumpで包む。PUMP_INTERVALが空ならループを進めるだけ
use v5.40;
use Plack::Builder;
use Plack::Util;
use OpenTelemetry 'otel_tracer_provider';

my $app = Plack::Util::load_psgi('app_otel.psgi');

# SIGTERMでも通常の終了処理を通し、キューに残ったスパンを送ってから終わる。
# SDKのshutdownはキューを送らずに捨てるので、force_flushを呼ぶ。
# SDK 0.100では、ログのエクスポーターがotlpのままだと、この後のプロセスの終了の途中で止まる。
# ログを送らないならOTEL_LOGS_EXPORTER=noneで起動する
if ( $ENV{SHUTDOWN_HOOK} ) {
    $SIG{TERM} = sub { exit 0 };
    END { otel_tracer_provider->force_flush(3)->get if $ENV{SHUTDOWN_HOOK} }
}

builder {
    enable '+Demo::OTelPump', interval => $ENV{PUMP_INTERVAL};
    $app;
};
