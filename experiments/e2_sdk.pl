use v5.40;
use OpenTelemetry::SDK;
use OpenTelemetry 'otel_tracer_provider';

my $provider = otel_tracer_provider;
my $tracer   = $provider->tracer( name => 'e2' );
$tracer->in_span( work => sub ( $span, $context ) {
    say 'provider:     ', ref $provider;
    say 'span:         ', ref $span;
    say 'is_recording: ', $span->recording ? 'true' : 'false';
    say 'trace_id:     ', $span->context->hex_trace_id;
});
