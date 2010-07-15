#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Data::Dump qw(dump);

use lib 'lib';

use_ok('MojoFacets::Import::CSV');

ok( my $o = MojoFacets::Import::CSV->new( path => 'data/ESB_izvadak-ziro.cp1250.csv' ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
