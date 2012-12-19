#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Data::Dump qw(dump);

use lib 'lib';

use_ok('MojoFacets::Import::DBF');

my $path = $ARGV[0] || (glob 'data/*/*/*.DBF')[0];
diag "using $path";

ok( my $o = MojoFacets::Import::DBF->new( full_path => $path ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
