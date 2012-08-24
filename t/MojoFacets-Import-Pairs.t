#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Data::Dump qw(dump);

use lib 'lib';

use_ok('MojoFacets::Import::Pairs');

my $path = $ARGV[0] || (glob 'data/lsblk/*.pairs')[0];
diag "using $path";

ok( my $o = MojoFacets::Import::Pairs->new( path => $path ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
