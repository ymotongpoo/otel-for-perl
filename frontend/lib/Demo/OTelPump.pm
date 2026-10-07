package Demo::OTelPump;
# IO::Asyncのループを回さないPSGIサーバーのための回避策。
# リクエストのたびにループを1回だけ進めて送信プロセスの結果を受け取り、
# intervalを設定した場合は、その秒数ごとにforce_flushでキューを送り出す。
use v5.40;
use parent 'Plack::Middleware';
use Plack::Util::Accessor qw( interval );
use IO::Async::Loop;
use OpenTelemetry 'otel_tracer_provider';
use Time::HiRes ();

my $last_flush = Time::HiRes::time;

sub call ( $self, $env ) {
    my $res = $self->app->($env);

    IO::Async::Loop->new->loop_once(0);    # SDKと同じループ（IO::Asyncの既定のループ）

    if ( my $interval = $self->interval ) {
        if ( Time::HiRes::time - $last_flush >= $interval ) {
            otel_tracer_provider->force_flush->get;
            $last_flush = Time::HiRes::time;
        }
    }
    return $res;
}

1;
