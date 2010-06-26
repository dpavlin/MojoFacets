package MojoFacets::Config;

use strict;
use warnings;

use base 'Mojolicious::Controller';

sub index {
	my $self = shift;

	my @config = (qw(
		MASTER
		MAX_FACETS
		PROFILE
	));

	foreach my $name ( @config ) {
		if ( my $val = $self->param($name) ) {
			$ENV{$name} = $val;
			warn "$name = $val\n";
		}
	}

	$self->render(
		config => \@config,
	);
}

1;
