#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Data::Dump qw(dump);

use lib 'lib';

use_ok('MojoFacets::Import::SQL');

my $sql = $ARGV[0] || (glob 'data/*.sql')[0];
diag "using $sql";

ok( my $o = MojoFacets::Import::SQL->new( path => $sql ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
