package MojoFacets::Import::CSV;

use warnings;
use strict;

use base 'Mojo::Base';

use File::Slurp;
use Data::Dump qw(dump);
use Encode;

__PACKAGE__->attr('path');
__PACKAGE__->attr('full_path');

sub data {
	my $self = shift;

	my $path = $self->path;

	my $data = read_file $self->full_path, { binmode => ':raw' }; # FIXME configurable!
	$data = decode('cp1250', $data);

	my @lines = split(/\r?\n/, $data);
	$data = { items => [] };

	my $delimiter = qr/,/;

	if ( $lines[0] !~ /;/ && $lines[1] =~ /;/ ) {
		shift @lines; # FIXME ship non-header line
		$delimiter = qr/;/;
	}

	my $header_line = shift @lines;

	my @header = split( $delimiter, $header_line );
	warn "# header ",dump( @header );

	while ( my $line = shift @lines ) {
		chomp $line;
		my @v = split($delimiter, $line);
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
