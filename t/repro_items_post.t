use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('MojoFacets');

# Test: POST to /data/items should work (currently fails with 404)
$t->post_ok('/data/items')
  ->status_is(302) # Expect 302 (redirect) because no path is provided, but verify it is NOT 404
  ->or(sub { diag "POST /data/items failed, status: " . $t->tx->res->code });

done_testing();
