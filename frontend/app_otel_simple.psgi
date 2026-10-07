# Batchの代わりにSimpleプロセッサーで、スパンが終わるたびに同期で送る
use v5.40;
use Plack::Util;
use OpenTelemetry 'otel_tracer_provider';
use OpenTelemetry::SDK::Trace::Span::Processor::Simple;
use OpenTelemetry::Exporter::OTLP;

BEGIN { $ENV{OTEL_TRACES_EXPORTER} = 'none' }    # SDKにBatchを組ませない
my $app = Plack::Util::load_psgi('app_otel.psgi');

otel_tracer_provider->add_span_processor(
    OpenTelemetry::SDK::Trace::Span::Processor::Simple->new(
        exporter => OpenTelemetry::Exporter::OTLP->new,
    ),
);

$app;
