use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Plack::Builder;
use Amon2::Lite;
use Cache::File;
use Encode;
use Digest::MD5 qw(md5_hex);
use Furl::HTTP;

my $cache = Cache::File->new(
    cache_root => '/tmp/NoPaste'
);

my $furl = Furl::HTTP->new(
    agent   => 'NoPaste',
    timeout => 10,
);

# put your configuration here
sub config {
    +{
    }
}

get '/' => sub {
    my $c = shift;
    return $c->render('index.tt');
};

post '/' => sub {
    my $c = shift;
    my $text = Encode::encode('utf8', $c->req->param('text'));
    my $key = md5_hex($text);

    $cache->set($key => $text);
    my $next_url = "/$key";

    $furl->request(
        method     => 'POST',
        host       => 'localhost',
        port       => 4979,
        path_query => '/notice',
        content    => +{
            channel => '#hackathon',
            message => "NoPaste http://@{[ $c->req->env->{HTTP_HOST} ]}$next_url"
        }
    );

    return $c->redirect($next_url);
};


get '/:key' => sub {
    my $c = shift;
    my $args = shift;
    my $key = $args->{key};

    my $text = Encode::decode('utf8', $cache->get($key));

    return $c->render('view.tt', +{
        text => $text
    });
};

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;
        $res->header( 'X-Content-Type-Options' => 'nosniff' );
        $res->header( 'X-Frame-Options' => 'DENY' );
    },
);

# load plugins
__PACKAGE__->load_plugins(
    'Web::CSRFDefender',
);

builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/static/|/robot\.txt$|/favicon.ico$)},
        root => File::Spec->catdir(dirname(__FILE__));
    enable 'Session::Cookie';

    __PACKAGE__->to_app();
};

__DATA__

@@ index.tt
<!doctype html>
<html>
<head>
    <met charst="utf-8">
    <title>NoPaste</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
<div id="wrap">
    <a href="/"><h1>NoPaste</h1></a>
    <div id="main">
    <form method="POST">
    <textarea name="text" id="text" rows="20" cols="60"></textarea>
    <input type="submit" id="submit" value="SEND!" />
    </form>
    </div>
<div/>
</body>
</html>

@@ view.tt
<!doctype html>
<html>
<head>
    <met charst="utf-8">
    <title>NoPaste</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body>
<div id="wrap">
    <a href="/"><h1>NoPaste</h1></a>
    <div id="main">
    <pre>[% text %]</pre>
    </div>
<div/>
</body>
</html>
