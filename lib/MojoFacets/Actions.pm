package MojoFacets::Actions;

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

sub _changes_path {
	my $self = shift;
	my $path = $self->param('path') || $self->session('path');
	$self->app->home->rel_dir('data') . '/' . $path . '.changes';
}

sub changes {
	my ( $self ) = @_;
	my $path = $self->param('path') || $self->session('path');
	my $commit = $self->param('commit');
	my ( $items, $unique2id );
	if ( my $apply_on_path = $self->param('apply_on_path') ) {
		$items = $MojoFacets::Data::loaded->{$apply_on_path}->{data}->{items};
		die "no $apply_on_path" unless $items;
		warn "using $items for $apply_on_path\n";
	}
	my $invalidate_columns;
	my $changes;
	my $stats;
	my $glob = $self->_changes_path . '/*';
	foreach my $t ( sort { $a cmp $b } glob $glob ) {
		my $e = retrieve($t);
		$e->{old} = [ $e->{old} ] unless ref $e->{old} eq 'ARRAY';
		if ( $items ) {
			die "no unique in ", dump($e) unless exists $e->{unique};
			my ($pk,$id) = %{ $e->{unique} };
			if ( ! $pk ) {
				$e->{_status} = 'skip';
				$stats->{skip}++;
				push @$changes, $e;
				next;
			}
			if ( ! defined $unique2id->{$pk} ) {
				warn "unique2id $pk on ", $#$items + 1 ," items\n";
				foreach my $i ( 0 .. $#$items ) {
					$unique2id->{$pk}->{ $items->[$i]->{$pk}->[0] } = $i;
				}
			}
			my $status = 'missing';
			if ( my $i = $unique2id->{$pk}->{$id} ) {
				$status = 'found';
				if ( $commit ) {
					my $column = $e->{column} or die "no column";
					$items->[$i]->{$column} = $e->{new};
					warn "# commit $i $column ",dump( $e->{new} );
					$invalidate_columns->{$column}++;
				}
			}
			$e->{_status} = $status;
			$stats->{$status}++;
		}
		push @$changes, $e;
	}

	foreach my $name ( keys %$invalidate_columns ) {
		MojoFacets::Data::__invalidate_path_column( $path, $name );
	}

	MojoFacets::Data::__path_modified( $path );

	my @loaded = MojoFacets::Data::__loaded_paths();
	warn "# loaded paths ",dump @loaded;

	$self->render( changes => $changes, loaded => \@loaded, stats => $stats );
}

sub remove {
	my $self = shift;

	if ( my $t = $self->param('time') ) {
		unlink $self->_changes_path . '/' . $t;
	}

	$self->redirect_to('/actions/changes');
}

1;
