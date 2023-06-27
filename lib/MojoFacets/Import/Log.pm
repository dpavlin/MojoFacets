package MojoFacets::Import::Log;

use warnings;
use strict;

use base 'Mojo::Base';

use Data::Dump qw(dump);

__PACKAGE__->attr('full_path');

sub ext { '.log' }

sub data {
	my $self = shift;

	my $path = $self->full_path;

	my $data = { items => [] };
	my $need_header = 1;

	my @header;
	@header = qw(Filesystem 1K-blocks Used Available Use% Mounted-on) if $path =~ m/date-df/;

	open(my $fh, $path) || die "$path: $!";
	while(<$fh>) {
		chomp;
		warn "## $_\n";

		chomp;
		my @v = split(/\s/, $_);

		my $item;
		foreach my $i ( 0 .. $#v ) {
			$item->{ $header[$i] || "f_$i" } = [ $v[$i] ];
		}
		push @{ $data->{items} }, $item;

		if ( $need_header ) {
			$data->{header} = [ @header ];
			$need_header = 0;
		}
	}

	return $data;

}

1
