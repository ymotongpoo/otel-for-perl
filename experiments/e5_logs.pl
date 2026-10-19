use v5.40;
use OpenTelemetry::SDK;
use OpenTelemetry qw( otel_tracer_provider otel_logger_provider );
use Log::Any '$log';
use Log::Any::Adapter 'OpenTelemetry';

my $tracer = otel_tracer_provider->tracer( name => 'e5' );
$tracer->in_span( report => sub ( $span, $context ) {
    $log->warn('rates service is slow');
    printf "span trace_id=%s span_id=%s\n", $span->context->hex_trace_id, $span->context->hex_span_id;
});
$log->info('outside of any span');
$log->debugf( 'formatted %s', 'message' );

# ログもBatchプロセッサーなので、明示的に送り出す
printf "logs force_flush=%s\n",   otel_logger_provider->force_flush(3)->get;
printf "traces force_flush=%s\n", otel_tracer_provider->force_flush(3)->get;
