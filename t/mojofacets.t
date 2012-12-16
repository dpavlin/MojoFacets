#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use Data::Dump qw(dump);

use lib 'lib';

use_ok('MojoFacets');

ok( my $o = MojoFacets->new, 'new' );

#ok( my $permanent = $o->_permanent_path('test'), '_permanent_path' );
#diag $permanent;
