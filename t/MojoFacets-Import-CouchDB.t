#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Data::Dump qw(dump);

use lib 'lib';

my $csv = $ARGV[0] || (glob 'data/*.couchdb')[0];
plan skip_all => "No .couchdb test file found" unless $csv;

use_ok('MojoFacets::Import::CouchDB');

diag "using $csv";

ok( my $o = MojoFacets::Import::CouchDB->new( full_path => $csv ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
done_testing();
