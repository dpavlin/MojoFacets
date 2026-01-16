use Mojo::Base -strict;
use Mojolicious::Lite;
use Test::More;
use Test::Mojo;

get '/with_default/:name' => { name => 0 } => sub {
  my $c = shift;
  $c->render(json => { param => $c->param('name') });
};

get '/with_undef/:name' => { name => undef } => sub {
  my $c = shift;
  $c->render(json => { param => $c->param('name') });
};

get '/no_default/:name' => sub {
  my $c = shift;
  $c->render(json => { param => $c->param('name') });
};

get '/optional(/:id)' => sub {
  my $c = shift;
  $c->render(json => { param => $c->param('id') });
};


my $t = Test::Mojo->new;

# Case 1: Default 0, no path param, with query param
$t->get_ok('/with_default?name=test')->status_is(200)
  ->json_is('/param', 0); # Expect 0 (shadowed)

# Case 2: Default undef, no path param, with query param
$t->get_ok('/with_undef?name=test')->status_is(200)
  ->json_is({ param => 'test' }); # Hope for 'test'

# Case 3: Optional placeholder
$t->get_ok('/optional?id=test')->status_is(200)
  ->json_is({ param => 'test' }); 

done_testing();
