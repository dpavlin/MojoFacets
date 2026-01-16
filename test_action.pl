use Mojo::Base -strict;
use Mojolicious::Lite;

get '/:action' => sub { shift->render(text => 'ok') };

app->start;
