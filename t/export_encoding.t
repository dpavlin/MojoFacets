use Mojo::Base -strict;
use utf8;
use Test::More;
use Test::Mojo;
use File::Spec;
use File::Path qw(mkpath);
use Encode;
use Time::HiRes qw(time);

my $t = Test::Mojo->new('MojoFacets');

# Create a unique test CSV with Croatian characters to avoid cache collision
my $ts = time();
my $data_dir = "data/test_encoding_$ts";
mkpath $data_dir unless -d $data_dir;
my $csv_rel_path = "test_encoding_$ts/utf8.csv";
my $csv_file = "data/$csv_rel_path";
my $content = "col1,col2\nčćžšđ,UTF-8 test\n";
open my $fh, '>:utf8', $csv_file or die $!;
print $fh $content;
close $fh;

# 1. Load the data
$t->get_ok('/data/load?path=' . $csv_rel_path)
  ->status_is(302);

# 2. Trigger export
$t->get_ok('/data/items?export=1&path=' . $csv_rel_path . '&columns=col1&columns=col2')
  ->status_is(200);

# 3. Find the exported file
my $export_dir = "public/export/$csv_rel_path";
my @exports = glob "$export_dir/*";
ok(scalar @exports > 0, "Export file created");

my $latest_export = (sort { -M $a <=> -M $b } @exports)[0];
diag "Latest export: $latest_export";

# 4. Check encoding
open my $efh, '<:raw', $latest_export or die $!;
my $exported_content = do { local $/; <$efh> };
close $efh;

# If it was exported correctly as UTF-8, it should match the original.
my $decoded_content = eval { decode('UTF-8', $exported_content, Encode::FB_CROAK) };
if ($@) {
    diag "Failed to decode UTF-8: $@";
    diag "Exported content (raw): " . unpack("H*", $exported_content);
    ok(0, "Exported content is valid UTF-8");
} else {
    diag "Decoded content: " . $decoded_content;
    ok($decoded_content =~ /čćžšđ/, "Exported content contains čćžšđ")
        or diag "Exported content (raw): " . unpack("H*", $exported_content);
}

# Clean up
unlink $csv_file;
rmdir $data_dir;
# Also clean up the cache file if we can guess its name
my $cache_name = $csv_rel_path;
$cache_name =~ s/\/+/_/g;
my $cache_path = "/tmp/mojo_facets.$cache_name.storable";
unlink $cache_path if -e $cache_path;

# Clean up export directory
my $export_parent = "public/export/test_encoding_$ts";
unlink $_ foreach glob "$export_dir/*";
rmdir $export_dir;
rmdir $export_parent;

done_testing();
