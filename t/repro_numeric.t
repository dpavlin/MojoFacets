use Mojo::Base -strict;
use Test::More;
use MojoFacets::Data;
use MojoFacets::Import::CSV;

# Test 1: Describe expected behavior for __stats detection
# MojoFacets::Data::__stats takes an array of hash refs and returns stats
# We want to check if it detects numeric fields

my $items = [
    { val => "123" },
    { val => "-123" },
    { val => "1.23" },
    { val => "-1.23" },
    
    { comma => MojoFacets::Import::CSV::sn_to_dec("1,23") },
    { comma => MojoFacets::Import::CSV::sn_to_dec("-1,23") },
    
    { mixed => "123" },
    { mixed => "a" },
];

# Call internal function __stats
my $stats = MojoFacets::Data::__stats($items);

# Verify "val" (standard numbers)
ok($stats->{val}->{numeric} == 4, "Detected 4 standard numeric values") 
    or diag "Found " . ($stats->{val}->{numeric} // 0);

# Verify "comma" (comma decimals)
# CURRENTLY EXPECTED TO FAIL
ok($stats->{comma}->{numeric} == 2, "Detected 2 comma decimal values") 
    or diag "Found " . ($stats->{comma}->{numeric} // 0);


# Test 2: Check CSV Import normalization (sn_to_dec behavior)
# We want to see if sn_to_dec handles text appropriately or if we need to improve it

my $converter = sub { MojoFacets::Import::CSV::sn_to_dec(shift) };

is($converter->("1.23"), "1.23", "Standard float preserved");
is($converter->("1,23"), "1.23", "Comma float normalized to dot (EXPECTED TO FAIL IF NOT IMPLEMENTED)");
is($converter->("-1,23"), "-1.23", "Negative comma float normalized (EXPECTED TO FAIL)");

done_testing();
