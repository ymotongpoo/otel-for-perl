use v5.40;
use OpenTelemetry::SDK;
use OpenTelemetry 'otel_tracer_provider';
use Time::HiRes 'time';

my $mode = shift // 'shutdown';
otel_tracer_provider->tracer( name => 'e6' )->in_span( "span-$_" => sub { } ) for 1 .. 3;

my $t = time;
if ( $mode eq 'flush' ) {
    my $r = otel_tracer_provider->force_flush(3)->get;
    printf "force_flush result=%s %.2fs\n", $r, time - $t;
    $t = time;
}
my $r = otel_tracer_provider->shutdown(3)->get;
printf "shutdown result=%s %.2fs\n", $r, time - $t;
