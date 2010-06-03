package MojoFacets::Changes;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Storable;
use Data::Dump qw(dump);
use MojoFacets::Data;

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

sub _edit_path {
	my $self = shift;
	my $path = $self->param('path') || $self->session('path');
	$self->app->home->rel_dir('data') . '/' . $path . '.edits';
}

sub edits {
	my ( $self ) = @_;
	my $path = $self->param('path') || $self->session('path');
	my ( $items, $unique2id );
	if ( my $apply_on_path = $self->param('apply_on_path') ) {
		$items = $MojoFacets::Data::loaded->{$apply_on_path}->{data}->{items};
		die "no $apply_on_path" unless $items;
		warn "using $items for $apply_on_path\n";
	}
	my $edits;
	my $stats;
	my $glob = $self->_edit_path . '/*';
	foreach my $t ( sort { $b cmp $a } glob $glob ) {
		my $e = retrieve($t);
		if ( $items ) {
			my ($pk,$id) = %{ $e->{unique} };
			if ( ! defined $unique2id->{$pk} ) {
				warn "unique2id $pk on ", $#$items + 1 ," items\n";
				foreach my $i ( 0 .. $#$items ) {
					$unique2id->{$pk}->{ $items->[$i]->{$pk}->[0] } = $i;
				}
			}
			my $i = $unique2id->{$pk}->{$id};
			my $status = defined $i ? 'found' : 'missing';
			$e->{_apply} = $status;
			$stats->{$status}++;
		}
		push @$edits, $e;
	}

	my @loaded = MojoFacets::Data::__loaded_paths();
	warn "# loaded paths ",dump @loaded;

	$self->render( edits => $edits, loaded => \@loaded, stats => $stats );
}

sub edit {
	my $self = shift;

	if ( my $t = $self->param('remove') ) {
		unlink $self->_edit_path . '/' . $t;
	}

	$self->redirect_to('/changes/edits');
}

1;
