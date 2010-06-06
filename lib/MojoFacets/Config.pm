package MojoFacets::Config;

use strict;
use warnings;

use base 'Mojolicious::Controller';

sub index {
	my $self = shift;

	foreach my $name ( qw( MASTER MAX_FACETS ) ) {
		if ( my $val = $self->param($name) ) {
			$ENV{$name} = $val;
			warn "$name = $val\n";
		}
	}

	$self->render;
}

1;
