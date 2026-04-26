#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Data::Dump qw(dump);

use lib 'lib';

my $sql = $ARGV[0] || (glob 'data/gadgetbridge/activity.sql')[0];

eval { require DBD::SQLite; };
if ($@ || !$sql) {
    plan skip_all => "DBD::SQLite not installed or no SQL test file found";
}

use_ok('MojoFacets::Import::SQL');

diag "using $sql";

ok( my $o = MojoFacets::Import::SQL->new( full_path => $sql ), 'new' );

ok( my $data = $o->data, 'data' );
diag dump($data);
done_testing();
