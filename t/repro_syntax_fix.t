use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Data::Dumper;

my $t = Test::Mojo->new('MojoFacets');

# 1. Setup: Load a temporary dataset (or use an existing one)
# We can simulate this by mocking the controller or just submitting code to a known dataset.
# Ideally, we should create a new small dataset, but for now we'll use the one loaded in memory or load one.
# Let's rely on the fact that we can push data via code/actions or just use an existing file.
# We'll use the 'george' file checked in previous tests.

my $path = 'george/converted_HR2424020063202824748_2025-01-01_2025-12-31.csv';
# Ensure it's loaded
# Ensure it's loaded by calling the index first (GET)
$t->get_ok("/data/items?path=$path&limit=1")->status_is(200);

# Wait for potential lazy loading if async? No, synchronous.
# However, the controller might redirect if 'columns' are not established.
# The previous GET should set up session.


# We use indirection to avoid the REGEX rewrite for the check!
# The rewrite only targets $row->{Literal}.
my $code = '
$row->{Iznos}++;
$out->{result} = $row->{Iznos};
my $r = $row;
my $col = "Iznos";
$out->{ref} = ref($r->{$col});
';

$t->post_ok('/data/items', form => {
    path => $path,
    code => $code,
    test => 1, # Run as test, don't commit to file
    limit => 1,
    'columns' => ['Iznos'],
})->status_is(200);

# 3. Verify Output
my $content = $t->tx->res->body;
if ($content =~ /<pre id=out>(.*?)<\/pre>/s) {
    my $dump = $1;
    diag "Output Dump: $dump";
    
    if ($dump =~ /ref.*ARRAY/) {
        pass("Structure preserved as ARRAY ref (Indirection confirms underlying structure)");
    } else {
        fail("Structure corrupted (not ARRAY ref)");
    }
} else {
    fail("Could not find output dump");
}

done_testing();
