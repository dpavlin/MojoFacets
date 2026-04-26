use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('MojoFacets');

# Test main page
$t->get_ok('/')->status_is(200);

# Test /data/columns route
$t->get_ok('/data/columns')->status_is(302);

# Test other routes to see if they exist
$t->get_ok('/data/items')->status_is(302); # Expect redirect if params missing, but not 404
$t->get_ok('/data/facet/test')->status_is(302); # Should redirect if no path, but not 500
$t->get_ok('/data/facet?name=test')->status_is(302); # Query param should also work
$t->get_ok('/data/load')->status_is(302); # It's ANY now according to routes, redirects if no path
$t->post_ok('/data/load')->status_is(302); # Should work

# Verify /data/index exists (used by data_index named route)
$t->get_ok('/data/index')->status_is(200);

# Check named routes existence via url_for
my $c = $t->app->build_controller;
eval { $c->url_for('data_index') };
ok(!$@, 'Route data_index should exist') or diag "data_index missing: $@";

eval { $c->url_for('profile_index') };
ok(!$@, 'Route profile_index should exist') or diag "profile_index missing: $@";

done_testing();
