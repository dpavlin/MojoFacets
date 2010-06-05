#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Data::Dump qw(dump);

use lib 'lib';

use_ok('MojoFacets::Import::HTMLTable');

ok( my $o = MojoFacets::Import::HTMLTable->new( dir => 'data/isi-citedref.html' ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
