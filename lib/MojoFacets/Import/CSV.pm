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

	open my $fh, "<:encoding($encoding)", $path or die "$path: $!";
	my $first = <$fh>;
	my $possible_delimiters;
	while ( $first =~ s/(\W)// ) {
		$possible_delimiters->{$1}++;
	}
	warn "# possible_delimiters = ",dump($possible_delimiters);
	seek $fh,0,0; # rewind for Text::CSV

	my @sep_by_usage = sort { $possible_delimiters->{$b} <=> $possible_delimiters->{$a} } keys %$possible_delimiters;
	my $sep_char = shift @sep_by_usage;
	while ( $sep_char =~ m/^\s$/ ) {
		warn "## skip whitespace separator ",dump($sep_char);
		$sep_char = shift @sep_by_usage;
	}

	warn "sep_char = [$sep_char] for $path\n";

	my $csv = Text::CSV->new ( { binary => 1, eol => $/, sep_char => $sep_char } )
		or die "Cannot use CSV: ".Text::CSV->error_diag ();

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
