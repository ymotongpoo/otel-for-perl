# Twiggyなどイベントループ型のサーバー向けの非同期版。計装はしていない
use v5.40;
use AnyEvent;
use AnyEvent::HTTP;
use Plack::Request;
use JSON::PP;

my $json = JSON::PP->new->canonical;
my $base = $ENV{RATES_URL} // 'http://backend:8080';

sub ($env) {
    my $req = Plack::Request->new($env);
    return [ 404, [ 'Content-Type' => 'text/plain' ], ['not found'] ]
        unless $req->path_info eq '/report';

    my $days     = $req->query_parameters->{days}     // 7;
    my $currency = $req->query_parameters->{currency} // 'USD';

    return sub ( $respond, @ ) {    # Twiggyは2つ目の引数にソケットを渡す
        # 集計の待ち時間をタイマーで模し、その間に他のリクエストを処理できるようにする
        my $timer;
        $timer = AnyEvent->timer( after => 0.003 * $days, cb => sub {
            undef $timer;
            http_get "$base/rates?currency=$currency", sub ( $body, $headers ) {
                my $rate = $json->decode($body)->{rate};
                $respond->( [
                    200, [ 'Content-Type' => 'application/json' ],
                    [ $json->encode( { days => $days, orders => 120 * $days, currency => $currency, rate => $rate } ) ],
                ] );
            };
        } );
    };
};
