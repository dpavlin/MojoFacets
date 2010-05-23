package MojoFacets::Changes;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Storable;

sub index {
	my $self = shift;

	my $max = $self->param('max') || 10;

	my $changes;
	foreach my $path ( sort { $b cmp $a } glob '/tmp/changes/*' ) {
		if ( $path =~ m{/((\d+\.\d+)\.data\.(.+))$} ) {
			push @$changes, { uid => $1, t => $2, action => $3 };
			last if $#$changes >= $max;
		} else {
			warn "ignore: $path\n";
		}
	}

	# Render template "changes/index.html.ep" with message
	$self->render(message => 'Latest Changes', changes => $changes );
}


sub view {
	my $self = shift;
	my $uid = $self->param('uid');
	$self->render( change => retrieve( "/tmp/changes/$uid" ), uid => $uid );
}

1;
