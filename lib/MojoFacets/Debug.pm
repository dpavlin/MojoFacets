package MojoFacets::Debug;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);

sub index {
	my $self = shift;


	$self->render(
		loaded => $MojoFacets::Data::loaded,
	);
}

1
