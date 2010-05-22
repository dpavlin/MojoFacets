package MojoFacets::Changes;

use strict;
use warnings;

use base 'Mojolicious::Controller';

sub index {
	my $self = shift;

	my $changes;
	foreach my $path ( glob '/tmp/changes/*' ) {
		if ( $path =~ m{/(\d+\.\d+)\.(.+)$} ) {
			push @$changes, [ $1, split(/\./, $2) ];
		} else {
			warn "ignore: $path\n";
		}
	}

	# Render template "changes/index.html.ep" with message
	$self->render(message => 'Latest Changes', changes => $changes );
}

1;
