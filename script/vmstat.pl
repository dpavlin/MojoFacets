#!/usr/bin/perl

use warnings;
use strict;

use Data::Dump qw(dump);
use Storable;
use Time::HiRes qw(time);

$|=1;

my $vmstat = 'vmstat 1';
$vmstat = join(' ', @ARGV, $vmstat) if @ARGV;

my $headers;
my @last;

sub emit {
	warn dump @_;
	Storable::store_fd $_[0], \*STDOUT 
		if defined $_[0]->{item};
}

warn "# vmstat $vmstat\n";
open(my $in, '-|', $vmstat);
while(<$in>) {
	chomp;
	my @v = split(/\s+/, $_);
	if ( ! $headers->{$#v} ) {
		$headers->{$#v} = [ @v ];
		warn "# headers ", dump $headers;
		next;
	}
	emit { row => [ @v ] };
	warn " $#v ",dump @v;
	my $diff;
	if ( @last ) {
		$diff->[$_] = $last[$_] - $v[$_] foreach ( 0 .. $#v );
		emit { diff => $diff };
	}
	@last = @v;

	my $item;
	my @header = @{ $headers->{$#v} };
	foreach my $i ( 0 .. $#header ) {
		$item->{ $header[$i] } = $v[$i];
		$item->{ $header[$i] . '.diff' } = $diff->[$i];
		$item->{t} = time();
	}
	emit { item => $item };

}
