package MojoFacets::Changes;

use strict;
use warnings;

use base 'Mojolicious::Controller';

sub index {
	my $self = shift;

	# Render template "changes/index.html.ep" with message
	$self->render(message => 'Latest Changes');
}

1;
