use strict;
use warnings;
use Data::Dumper;

print "--- Demonstration of scalar vs array ref modification ---\n";

# Case 1: Scalar
my $row_scalar = { val => 10 };
print "Original Scalar: " . Dumper($row_scalar);
$row_scalar->{val}++;
print "After \$row->{val}++: " . Dumper($row_scalar);

# Case 2: Array Ref (MojoFacets style)
my $row_array = { val => [10] };
print "\nOriginal Array Ref: " . Dumper($row_array);

# Incorrect usage
print "Attempting \$row->{val}++ on array ref...\n";
{
    no warnings 'numeric'; # Suppress warning "Argument ... isn't numeric in postincrement"
    $row_array->{val}++;
}
print "Result (Reference modified/corrupted): " . Dumper($row_array);

# Case 3: Correct usage
$row_array = { val => [10] }; # Reset
print "\nReset Array Ref: " . Dumper($row_array);
print "Attempting \$row->{val}->[0]++ ...\n";
$row_array->{val}->[0]++;
print "Result (Correct value increment): " . Dumper($row_array);

print "\n--- User Goal ---\n";
print "If user types: \$row->{val}++\n";
print "We want it to apply to ALL elements in the array ref.\n";

my $row_multi = { val => [10, 20, 30] };
print "\nMulti-value Array: " . Dumper($row_multi);
print "Applying ++ to all elements via loop...\n";

# Desired transformation
foreach my $v (@{$row_multi->{val}}) {
    $v++;
}
print "Result: " . Dumper($row_multi);
