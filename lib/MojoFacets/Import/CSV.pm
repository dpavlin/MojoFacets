package MojoFacets::Import::CSV;

use warnings;
use strict;

use base 'Mojo::Base';

use Text::CSV;
use Data::Dump qw(dump);

__PACKAGE__->attr('full_path');

sub data {
	my $self = shift;

	my $path = $self->full_path;

	my $encoding = 'utf-8';
	if ( $path =~ m/\.(\w+).csv/i ) {
		$encoding = $1;
	}

	my $data = { items => [] };
	my @header;

	my $csv = Text::CSV->new ( { binary => 1, eol => $/ } )
		or die "Cannot use CSV: ".Text::CSV->error_diag ();

	open my $fh, "<:encoding($encoding)", $path or die "$path: $!";
	while ( my $row = $csv->getline( $fh ) ) {
		if ( ! @header ) {
			@header = @$row;
			next;
		}
		my $item;
		foreach my $i ( 0 .. $#{$row} ) {
			$item->{ $header[$i] || "f_$i" } = [ $row->[$i] ];
		}
		push @{ $data->{items} }, $item;
	}

	$csv->eof or $csv->error_diag();
	close $fh;

	$data->{header} = [ @header ];
	
	return $data;

}

1
