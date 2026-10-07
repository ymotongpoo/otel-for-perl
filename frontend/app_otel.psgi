use v5.40;
use OpenTelemetry::SDK;
use OpenTelemetry 'otel_tracer_provider';
use OpenTelemetry::Instrumentation 'HTTP::Tiny';
use Plack::Builder;
use Plack::Request;
use JSON::PP;
use Demo::Report;

my $json   = JSON::PP->new->canonical;
my $tracer = otel_tracer_provider->tracer( name => 'demo-report' );

my $app = sub ($env) {
    my $req = Plack::Request->new($env);
    return [ 404, [ 'Content-Type' => 'text/plain' ], ['not found'] ]
        unless $req->path_info eq '/report';

    my $days     = $req->query_parameters->{days}     // 7;
    my $currency = $req->query_parameters->{currency} // 'USD';

    my $totals = $tracer->in_span(
        aggregate => ( attributes => { 'report.days' => $days } ) => sub ( $span, $context ) {
            Demo::Report::aggregate($days);
        },
    );
    my $rate = Demo::Report::fetch_rate($currency);

    return [
        200, [ 'Content-Type' => 'application/json' ],
        [ $json->encode( { %$totals, currency => $currency, rate => $rate } ) ],
    ];
};

builder {
    enable 'OpenTelemetry';
    $app;
};
