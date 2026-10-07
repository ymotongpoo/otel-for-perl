# app_otel.psgiをDemo::OTelPumpで包む。PUMP_INTERVALが空ならループを進めるだけ
use v5.40;
use Plack::Builder;
use Plack::Util;
use OpenTelemetry 'otel_tracer_provider';

my $app = Plack::Util::load_psgi('app_otel.psgi');

# SIGTERMでも通常の終了処理を通し、キューに残ったスパンを送ってから終わる。
# SDK 0.028のshutdownはキューを送らずに捨てるので、force_flushを呼ぶ
if ( $ENV{SHUTDOWN_HOOK} ) {
    $SIG{TERM} = sub { exit 0 };
    END { otel_tracer_provider->force_flush(3)->get if $ENV{SHUTDOWN_HOOK} }
}

builder {
    enable '+Demo::OTelPump', interval => $ENV{PUMP_INTERVAL};
    $app;
};
