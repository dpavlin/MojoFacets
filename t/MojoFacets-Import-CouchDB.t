#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Data::Dump qw(dump);

use lib 'lib';

use_ok('MojoFacets::Import::CouchDB');

my $csv = $ARGV[0] || (glob 'data/*.couchdb')[0];
diag "using $csv";

ok( my $o = MojoFacets::Import::CouchDB->new( full_path => $csv ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
