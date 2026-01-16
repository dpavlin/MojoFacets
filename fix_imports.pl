#!/usr/bin/perl

use strict;
use warnings;
use File::Find;

find(\&fix_has, 'lib/MojoFacets/Import');

sub fix_has {
    my $file = $File::Find::name;
    return unless -f $file && $file =~ /\.pm$/;
    
    print "Fixing $file\n";
    
    open my $in, '<', $file or die "Can't read $file: $!";
    my @lines = <$in>;
    close $in;
    
    open my $out, '>', $file or die "Can't write $file: $!";
    
    foreach my $line (@lines) {
        # Fix has statements with proper quoting
        if ($line =~ /^\s*has\s+['"]([^'"]+)['"]\s*;/) {
            my $attr = $1;
            $line = "has '$attr';";
        } elsif ($line =~ /^\s*no attributes/) {
            next; # Remove these lines
        }
        print $out $line;
    }
    
    close $out;
}
