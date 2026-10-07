package Demo::Report;
use v5.40;
use HTTP::Tiny;
use JSON::PP;
use Time::HiRes ();

my $http = HTTP::Tiny->new( timeout => 5, keep_alive => $ENV{RATES_KEEP_ALIVE} // 1 );
my $json = JSON::PP->new->canonical;

# 1日分の注文を集計するのに3ミリ秒かかる処理の代わり
sub aggregate ($days) {
    Time::HiRes::sleep( 0.003 * $days );
    return { days => $days, orders => 120 * $days };
}

# 下流のratesサービスから為替レートを取得する
sub fetch_rate ($currency) {
    my $base = $ENV{RATES_URL} // 'http://backend:8080';
    my $res  = $http->get("$base/rates?currency=$currency");
    die "rates: $res->{status} $res->{reason}\n" unless $res->{success};
    return $json->decode( $res->{content} )->{rate};
}

1;
