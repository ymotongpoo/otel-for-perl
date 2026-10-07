use v5.40;
use Plack::Request;
use JSON::PP;
use Demo::Report;

my $json = JSON::PP->new->canonical;

my $app = sub ($env) {
    my $req = Plack::Request->new($env);
    return [ 404, [ 'Content-Type' => 'text/plain' ], ['not found'] ]
        unless $req->path_info eq '/report';

    my $days     = $req->query_parameters->{days}     // 7;
    my $currency = $req->query_parameters->{currency} // 'USD';

    my $totals = Demo::Report::aggregate($days);
    my $rate   = Demo::Report::fetch_rate($currency);

    return [
        200, [ 'Content-Type' => 'application/json' ],
        [ $json->encode( { %$totals, currency => $currency, rate => $rate } ) ],
    ];
};
