package MojoFacets::Import::CSV;

use warnings;
use strict;

use Mojo::Base -base;

use Text::CSV;
use Data::Dump qw(dump);

has 'full_path';

sub ext { '\.[ct]sv$' };

sub sn_to_dec {
    my $num = shift;

    if ($num =~ /^([+-]?)(\d*)(\.?)(\d*)[Ee]([-+]?\d+)$/) {
        my ($sign, $int, $period, $dec, $exp) = ($1, $2, $3, $4, $5);

        if ($exp < 0) {
            my $len = 1 - $exp;
            $int = ('0' x ($len - length $int)) . $int if $len > length $int;
            substr $int, $exp, 0, '.';
            return $sign.$int.$dec;

        } elsif ($exp > 0) {
            $dec .= '0' x ($exp - length $dec) if $exp > length $dec;
            substr $dec, $exp, 0, '.' if $exp < length $dec;
            return $sign.$int.$dec;

        } else {
            return $sign.$int.$period.$dec;
        }
    }

    return $num;
}


sub data {
	my $self = shift;

	my $path = $self->full_path;

	my $encoding = 'utf-8';
	if ( $path =~ m/\.([\w\-]+).[ct]sv/i ) {
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
		last if $sep_char eq "\t" && $path =~ m/\.tsv$/i;
		warn "## skip whitespace separator ",dump($sep_char);
		$sep_char = shift @sep_by_usage;
	}

	while ( $sep_char =~ m/^\"$/ ) {
		warn "## skip quote separator ",dump($sep_char);
		$sep_char = shift @sep_by_usage;
	}

	if ( $sep_char !~ m/,/ && $possible_delimiters->{','} && $path =~ m/\.csv/i ) {
		$sep_char = ',';
		warn "## csv file detected so prefer , as separator";
	}

	warn "sep_char = [$sep_char] for $path\n";

	my $csv = Text::CSV->new ( { binary => 1, eol => $/, sep_char => $sep_char } )
		or die "Cannot use CSV: ".Text::CSV->error_diag ();

	while ( my $row = $csv->getline( $fh ) ) {
		if ( ! @header ) {
			@header = @$row;
			foreach my $h ( @header ) {
				next unless defined $h;
				$h =~ s/^\x{FEFF}//; # remove BOM
				$h =~ s/^["']+//;    # remove leading quotes
				$h =~ s/["']+$//;    # remove trailing quotes
			}
			$header[0] =~ s/^#// if $path =~ m/\.tsv/i; # remove hash from 1st column
			next;
		}
		my $item;
		foreach my $i ( 0 .. $#{$row} ) {
			$item->{ $header[$i] || "f_$i" } = [ sn_to_dec $row->[$i] ];
		}
		push @{ $data->{items} }, $item;
	}

	$csv->eof or $csv->error_diag();
	close $fh;

	$data->{header} = [ @header ];
	
	return $data;

}

1
