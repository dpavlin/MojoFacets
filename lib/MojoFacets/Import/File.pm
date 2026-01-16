package MojoFacets::Import::File;

use warnings;
use strict;

use Mojo::Base -base;

use HTML::TableExtract;
use File::Slurp;
use Data::Dump qw(dump);
use JSON;

has 'path';
has 'full_path';

sub ext { '\.(js(on)?|txt)$' }

sub data {
	my $self = shift;

	my $path = $self->path;
	if ( ! $path ) {
		$path = $self->full_path || die "no path or full_path";
		$path =~ s{^.+/([^/]+)$}{$1};
	}

	# we could use Mojo::JSON here, but it's too slow
#	$data = from_json read_file $path;
	my $data = read_file $self->full_path;
	warn "# data snippet: ", substr($data,0,200);
	my @header;
	if ( $path =~ m/\.js(on)?/ ) {
		Encode::_utf8_on($data);
		$data = from_json $data;
	} elsif ( $path =~ m/\.txt/ ) {
		my @lines = split(/\r?\n/, $data);
		$data = { items => [] };

		my $header_line = shift @lines;
		my $multiline = $header_line =~ s/\^//g;
		@header = split(/\|/, $header_line );
		warn "# header ", dump( @header );
		while ( my $line = shift @lines ) {
			$line =~ s/\^//g;
			chomp $line;
			my @v = split(/\|/, $line);
			while ( @lines && $#v < $#header ) {
				$line = $lines[0];
				$line =~ s/\^//g;
				chomp $line;
				my @more_v = split(/\|/, $line);
				if ( $#v + $#more_v > $#header ) {
					warn "short line: ",dump( @v );
					last;
				}
				shift @lines;
				$v[ $#v ] .= shift @more_v if @more_v;
				push @v, @more_v if @more_v;

				if ( $#v > $#header ) {
					die "# splice $#header ", dump( @v );
					@v = splice @v, 0, $#header;
				}
			}
			my $item;
			foreach my $i ( 0 .. $#v ) {
				$item->{ $header[$i] || "f_$i" } = [ $v[$i] ];
			}
			push @{ $data->{items} }, $item;
		}
	} else {
		warn "file format unknown $path";
	}

	$data->{header} = [ @header ];
	
	return $data;

}

1
