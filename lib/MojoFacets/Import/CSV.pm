package MojoFacets::Import::CSV;

use warnings;
use strict;

use base 'Mojo::Base';

use File::Slurp;
use Data::Dump qw(dump);
#use Encode;

__PACKAGE__->attr('path');
__PACKAGE__->attr('full_path');

sub data {
	my $self = shift;

	my $path = $self->path;

	my $data = read_file $self->full_path, { binmode => ':cp1250' }; # FIXME configurable!

	my @lines = split(/\r?\n/, $data);
	$data = { items => [] };

	my $delimiter = qr/;/;

	shift @lines; # FIXME ship non-header line
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
