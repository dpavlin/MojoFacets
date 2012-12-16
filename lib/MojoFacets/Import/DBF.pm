package MojoFacets::Import::DBF;

use warnings;
use strict;

use base 'Mojo::Base';

use XBase;

use Data::Dump qw(dump);

__PACKAGE__->attr('full_path');

sub ext { '.dbf' };

sub data {
	my $self = shift;


	my $table = new XBase $self->full_path or die XBase->errstr;

	my $data = {
		header => [ $table->field_names ],
		types  => [ $table->field_types ],
		lenghts=> [ $table->field_lengths ],
		decimals=> [ $table->field_decimals ],
		items => [],
	};

	for (0 .. $table->last_record) {
		my $item = $table->get_record_as_hash($_);
		warn "$_ ",dump($item);
		push @{ $data->{items} }, $item;
	}

	return $data;

}

1
