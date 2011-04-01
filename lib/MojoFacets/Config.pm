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
		DEBUG
	));

	foreach my $name ( @config ) {
		my $val = $self->param($name);
		if ( defined $val ) {
			$ENV{$name} = $val;
			warn "$name = $val\n";
		}
	}

	$self->render(
		config => \@config,
	);
}

1;
