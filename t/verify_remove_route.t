use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('MojoFacets');

# Test 1: Verify /data/load accepts GET (was POST only)
$t->get_ok('/data/load')
  ->status_is(302) # Should redirect, probably to index if no path
  ->or(sub { diag "GET /data/load failed, status: " . $t->tx->res->code });

# Test 2: Verify /data/remove redirects to /data/index
# We don't need to actually remove a file, just check the redirect behavior
# If we provide a dummy path, it should still redirect to /data/index (after checking path)

$t->get_ok('/data/remove?path=/tmp/mojo_facets.dummy_test_file.csv.storable')
  ->status_is(302)
  ->header_is(Location => '/data/index') # This verifies the logic change in Data.pm
  ->or(sub { diag "Location header is: " . $t->tx->res->headers->location });

done_testing();
