package MojoFacets::Import::CSV;

use warnings;
use strict;

use base 'Mojo::Base';

use File::Slurp;
use Data::Dump qw(dump);
use Encode;

__PACKAGE__->attr('full_path');

my $null = ''; # FIXME undef?

sub _split_line {
	my ( $delimiter, $line ) = @_;
	my @v;
	while ( $line ) {
		my $v;
		if ( $line =~ s/^"// ) {
			$line =~ s/""/_qq_/gc;
			$line =~ s/^\s*([^"]*)\s*"\Q$delimiter\E?// || die "can't parse [$line] ",dump(@v);
			$v = $1;
		} elsif ( $line =~ s/^\s*([^\Q$delimiter\E]+)\s*\Q$delimiter\E?// ) {
			$v = $1;
		} elsif ( $line =~ s/^\s*\Q$delimiter\E// ) {
			$v = $null;
		} else {
			die "can't parse [$line]\n";
		}

		$v =~ s/^\s*(.+?)\s*$/$1/;
		$v = $null if $v eq '_qq_'; # "" field which is not first one
		$v =~ s/_qq_/"/g;
		$v =~ s/_LF_/\n/g;
		push @v, $v;
	}

	return @v;
}

sub data {
	my $self = shift;

	my $path = $self->full_path;

	my $data = read_file $path, { binmode => ':raw' }; # FIXME configurable!
	my $encoding = 'utf-8';
	if ( $path =~ m/\.(\w+).csv/i ) {
		$encoding = $1;
	}
	warn "decoding ", length($data), " bytes using $encoding\n";
	$data = decode($encoding, $data);

	# multi-line strings
	while ( $data =~ s/(,"[^"]*)[\n\r]+([^"]*)/$1_LF_$2/sg ) {
		 warn "multi-line quoted CSV data found";
	}

	my @lines = split(/\r?\n/, $data);
	$data = { items => [] };

	my $delimiter = ',';

	if ( $lines[0] !~ m/,/ ) {
		if ( $lines[0] =~ m/;/ ) {
			$delimiter = ';';
		} elsif ( $lines[0] !~ /;/ && $lines[1] =~ /;/ ) {
			shift @lines; # FIXME skip non-header line
			$delimiter = ';';
		}
	}

	warn "$path ", $#lines + 1, " lines encoding: $encoding delimiter:",dump($delimiter);

	my $header_line = shift @lines;

	my @header = _split_line( $delimiter, $header_line );
	warn "# header ",dump( @header );

	while ( my $line = shift @lines ) {
		chomp $line;
		my @v = _split_line($delimiter, $line);
		my $item;
		foreach my $i ( 0 .. $#v ) {
			$item->{ $header[$i] || "f_$i" } = [ $v[$i] ];
		}
		push @{ $data->{items} }, $item;
	}

	$data->{header} = [ @header ];
	
	return $data;

}

1
