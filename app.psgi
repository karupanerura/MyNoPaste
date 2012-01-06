use strict;
use warnings;
use utf8;
use Plack::Builder;
use File::Spec;
use File::Basename;
use Amon2::Lite;
use Cache::File;
use Encode;
use Digest::MD5 qw(md5_hex);
use Furl::HTTP;

my $cache = Cache::File->new(
    cache_root      => '/tmp/NoPaste',
    default_expires => '7 d'
);
my $encoder = Encode::find_encoding('utf8');
my $furl = Furl::HTTP->new(
    agent   => 'NoPaste',
    timeout => 10,
);

# put your configuration here
sub config {
    +{
        'Text::Xslate' => +{
            syntax => 'Kolon',
            suffix => '.tx',
            cache  => 1,
        },
    }
}

get '/' => sub {
    my $c = shift;
    return $c->render('index.tx');
};

post '/post' => sub {
    my $c = shift;
    my $text = $encoder->encode($c->req->param('text'));
    my $key = md5_hex($text);

    $cache->set($key => $text);
    my $next_url = "/post/$key";

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


get '/post/:key' => sub {
    my $c = shift;
    my $args = shift;
    my $key = $args->{key};

    my $text = $encoder->decode($cache->get($key));

    return $c->render('view.tx', +{
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
    enable 'Session::Cookie';
    enable 'Static',
        path => qr{^/(?:css)/},
        root => File::Spec->catdir(dirname(__FILE__), 'htdocs');

    __PACKAGE__->to_app();
};

__DATA__

@@ base.tx
<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <title>NoPaste</title>
    <meta name="description" content="Local NoPaste" />
    <meta name="author" content="karupanerura" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />

    <!-- Le HTML5 shim, for IE6-8 support of HTML elements -->
    <!--[if lt IE 9]>
      <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]-->

    <!-- Le styles -->
    <link rel="stylesheet" href="http://twitter.github.com/bootstrap/1.4.0/bootstrap.min.css" />
    <link rel="stylesheet" href="/css/main.css" />
  </head>

  <body>
    <div class="topbar">
      <div class="fill">
        <div class="container">
          <a class="brand" href="/">NoPaste</a>
        </div>
      </div>
    </div>

    <div class="container">
      <div class="content">
        <div class="page-header">
          <h1><: $title :> - <small><: $message :></small></h1>
        </div>
: block content -> {
        <div class="row">
          <div class="span10">
            <h2>Main content</h2>

          </div>
          <div class="span4">
            <h3>Secondary content</h3>
          </div>
: }
        </div>
      </div>

      <footer>
        <p>&copy; karupanerura 2012</p>

      </footer>
    </div> <!-- /container -->
  </body>
</html>


@@ index.tx
: cascade base {
:   title   => "Post",
:   message => "Post to #hackthron.",
: };
: around content -> {
        <div class="row">
          <form method="POST" action="/post">
            <textarea name="text" id="text"></textarea>
            <input type="submit" id="submit" value="SEND!" />
          </form>
        </div>
: }

@@ view.tx
: cascade base {
:   title   => "View",
:   message => "#hackthron",
: };
: around content -> {
        <div class="row">
          <pre><: $text :></pre>
        </div>
: }
