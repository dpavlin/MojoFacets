package MojoFacets::Config;

use strict;
use warnings;

use base 'Mojolicious::Controller';

sub index {
	my $self = shift;

	if ( my $master = $self->param('MASTER') ) {
		$ENV{MASTER} = $master;
		warn "MASTER = $master\n";
	}

	$self->render;
}

1;
