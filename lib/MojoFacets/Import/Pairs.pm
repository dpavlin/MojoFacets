package MojoFacets::Import::Pairs;

use warnings;
use strict;

use base 'Mojo::Base';

use Data::Dump qw(dump);

__PACKAGE__->attr('full_path');

sub data {
	my $self = shift;

	my $path = $self->full_path;

	my $data = { items => [] };
	my $need_header = 1;

	open(my $fh, $path) || die "$path: $!";
	while(<$fh>) {
		chomp;
		warn "## $_\n";
		my @header;
		my %item = (
			map {
				my ($k,$v) = split(/="/,$_,2);
				push @header, $k if $need_header;
				( $k => $v );
			} split(/"\s/, $_)
		);
		push @{ $data->{items} }, \%item;

		if ( $need_header ) {
			$data->{header} = [ @header ];
			$need_header = 0;
		}
	}

	return $data;

}

1
