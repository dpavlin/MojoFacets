package MojoFacets::Import::HTMLTable;

use warnings;
use strict;

use base 'Mojo::Base';

use HTML::TableExtract;
use File::Slurp;
use Data::Dump qw(dump);

__PACKAGE__->attr('dir');

sub data {
	my $self = shift;

	my $items;
	my $stats;
	my @header;

	foreach my $file ( glob $self->dir . '/*.html' ) {
		warn "# file $file\n";
		my $te = HTML::TableExtract->new(
			keep_headers => 1,
		);

		$te->parse( scalar read_file $file );

		foreach my $ts ($te->tables) {
			warn "# table coords ", join(',', $ts->coords), "\n";
			warn "# hrow ", dump( $ts->hrow() ), "\n";
			my @column_map = $ts->column_map;
			warn "# column_map ", dump( @column_map );
			next unless $#column_map == 8;
			foreach my $row ($ts->rows) {
				warn "# row ", dump( $row ),"\n";
				if ( ! $stats->{$file} ) {
					if ( ! @header ) {
						@header = @$row;
						warn "# new header ",dump(@header);
					} else {
						my $o = join('|', @header);
						my $n = join('|', @$row);
						if ( $o eq $n ) {
							warn "# same header again in $file skipping\n";
						} else {
							warn "# header $n changed from $o in $file";
							push @$items, $row;
							$stats->{$file}++;
						}
					}
				} else {
					push @$items, $row;
					$stats->{$file}++;
				}
			}
		}

	}

	return {
		header => [ @header ],
		items => $items,
		stats => $stats,
	}
}

1
