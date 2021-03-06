package MojoFacets::Changes;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Storable;
use Data::Dump qw(dump);
use MojoFacets::Data;

sub _changes_path {
	my $self = shift;
	my $path = $self->param('path') || $self->session('path');
	$self->app->home->rel_file('data') . '/' . $path . '.changes';
}

sub _hash_eq {
	my ( $a_ref, $b_ref ) = @_;

	warn "# _hash_eq ",dump($a_ref,$b_ref);

	local $Storable::canonical = 1;
	return eval { Storable::freeze( $a_ref ) } eq eval { Storable::freeze( $b_ref ) };
}

sub index {
	my ( $self ) = @_;
	my $path = $self->param('path') || $self->session('path');
	my $on_path = $self->param('on_path');
	my $commit = $self->param('commit');
	my $apply = $self->param('apply');
	my ( $items, $unique2id );
	if ( $on_path ) {
		$items = $MojoFacets::Data::loaded->{$on_path}->{data}->{items};
		if ( ! $items ) {
			warn "$on_path not loaded";
			return $self->redirect_to('/data/index?path=' . $on_path);
		}
		warn "using ", $#$items + 1, " items from $on_path\n";
	}
	my $invalidate_columns;
	my $changes;
	my $stats;
	my $glob = $self->_changes_path . '/*';
	my $status = 'unknown';
	foreach my $t ( sort { $a cmp $b } glob $glob ) {
		my $e = retrieve($t);
		$e->{old} = [ $e->{old} ] unless ref $e->{old} eq 'ARRAY';
		if ( $items && exists $e->{unique} ) {
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
			$status = 'missing';
			if ( my $i = $unique2id->{$pk}->{$id} ) {
				if ( _hash_eq( $e->{old}, $items->[$i]->{$e->{column}} ) ) {
					$status = 'found';
					if ( $commit ) {
						my $column = $e->{column} or die "no column";
						$items->[$i]->{$column} = $e->{new};
						warn "# commit $i $column ",dump( $e->{new} );
						$invalidate_columns->{$column}++;
					}
				} else {
					$status = 'source-changed';
				}
			}
		} elsif ( my $code = $e->{code} ) {
			if ( $commit ) {
				my $commit_changed;
				my $t = time();
				foreach my $i ( 0 .. $#$items ) {
					MojoFacets::Data::__commit_path_code( $on_path, $i, $code, \$commit_changed );
				}
				$t = time() - $t;
				$self->stash( 'commit_changed', $commit_changed );
				warn "commit_changed in $t s ",dump( $e->{commit_changed}, $commit_changed );
				$e->{commit_changed_this} = $commit_changed;
				MojoFacets::Data::__invalidate_path_column( $on_path, $_ ) foreach keys %$commit_changed;
				MojoFacets::Data::__path_rebuild_stats( $on_path );
			}
			$status = 'code';
			if ( ( $apply || $commit ) && $e->{commit_changed} ) {
				$status = 'found';
				foreach my $c ( keys %{ $e->{commit_changed} } ) {
					$status = 'missing' unless defined $MojoFacets::Data::loaded->{$path}->{stats}->{$c};
				}
			}
		} else {
			$status = 'unknown';
		}

		$e->{_status} = $status;
		$stats->{$status}++;

		push @$changes, $e;
	}


	foreach my $name ( keys %$invalidate_columns ) {
		MojoFacets::Data::__invalidate_path_column( $on_path, $name );
	}

	MojoFacets::Data::__path_modified( $on_path );

	my @loaded = MojoFacets::Data::__loaded_paths();
	warn "# loaded paths ",dump @loaded;

	$self->render(
		on_path => $on_path || $path,
		changes => $changes,
		loaded => \@loaded,
		stats => $stats,
	);
}

sub remove {
	my $self = shift;

	if ( my $t = $self->param('time') ) {
		unlink $self->_changes_path . '/' . $t;
	}

	return $self->redirect_to('/changes');
}

1;
