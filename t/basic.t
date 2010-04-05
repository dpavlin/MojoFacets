#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 5;
use Test::Mojo;

use_ok('MojoFacets');

# Test
my $t = Test::Mojo->new(app => 'MojoFacets');
$t->get_ok('/')->status_is(200)->content_type_is('text/html')
  ->content_like(qr/Mojo/i);
