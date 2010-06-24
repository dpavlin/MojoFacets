package MojoFacets::Actions;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Storable;
use Data::Dump qw(dump);

sub index {
	my $self = shift;

	my $max = $self->param('max') || 50;
	my $action_regex = join('|', $self->param('action_filter'));
	warn "# action_regex $action_regex\n";

	my $actions;

	my $stats;
	foreach my $path ( sort { $b cmp $a } glob '/tmp/actions/*' ) {
		if ( $path =~ m{/((\d+\.\d+)\.data\.(.+))$} ) {
			my ( $uid, $t, $action ) = ( $1, $2, $3 );
			$stats->{$action}++;
			next if $action_regex && $action !~ m/^($action_regex)$/;
			push @$actions, { uid => $uid, t => $t, action => $action }
				if $#$actions < $max;
		} else {
			warn "ignore: $path\n";
		}
	}

	# Render template "actions/index.html.ep" with message
	$self->render(actions => $actions, stats => $stats );
}


sub view {
	my $self = shift;
	my $uid = $self->param('uid');
	$self->render( change => retrieve( "/tmp/actions/$uid" ), uid => $uid );
}

1;
