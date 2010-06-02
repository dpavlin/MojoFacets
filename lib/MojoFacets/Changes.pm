package MojoFacets::Changes;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Storable;

sub index {
	my $self = shift;

	my $max = $self->param('max') || 50;
	my $action_regex = join('|', $self->param('action_filter'));
	warn "# action_regex $action_regex\n";

	my $actions;

	my $changes;
	foreach my $path ( sort { $b cmp $a } glob '/tmp/changes/*' ) {
		if ( $path =~ m{/((\d+\.\d+)\.data\.(.+))$} ) {
			my ( $uid, $t, $action ) = ( $1, $2, $3 );
			$actions->{$action}++;
			next if $action_regex && $action !~ m/^($action_regex)$/;
			push @$changes, { uid => $uid, t => $t, action => $action }
				if $#$changes < $max;
		} else {
			warn "ignore: $path\n";
		}
	}

	# Render template "changes/index.html.ep" with message
	$self->render(message => 'Latest Changes', changes => $changes, actions => $actions );
}


sub view {
	my $self = shift;
	my $uid = $self->param('uid');
	$self->render( change => retrieve( "/tmp/changes/$uid" ), uid => $uid );
}

sub edits {
	my ( $self ) = @_;
	my $path = $self->param('path') || $self->session('path');
	my $edit_path = $self->app->home->rel_dir('data') . '/' . $path . '.edits';
	my $edits;
	foreach my $t ( sort { $b <=> $a } glob $edit_path . '/*' ) {
		push @$edits, retrieve("$t");
	}
	$self->render( edits => $edits );
}

1;
