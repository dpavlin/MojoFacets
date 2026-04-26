#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Data::Dump qw(dump);

use lib 'lib';

my $path = $ARGV[0] || (glob 'data/*/*/*.DBF')[0];
plan skip_all => "No .DBF test file found" unless $path;

use_ok('MojoFacets::Import::DBF');

diag "using $path";

ok( my $o = MojoFacets::Import::DBF->new( full_path => $path ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
done_testing();
