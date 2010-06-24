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
	$self->app->home->rel_dir('data') . '/' . $path . '.changes';
}

sub index {
	my ( $self ) = @_;
	my $path = $self->param('path') || $self->session('path');
	my $commit = $self->param('commit');
	my ( $items, $unique2id );
	if ( $path ) {
		$items = $MojoFacets::Data::loaded->{$path}->{data}->{items};
		if ( ! $items ) {
			warn "$path not loaded";
			$self->session('path', $path);
			$self->redirect_to('/data/index');
			return;
		}
		warn "using $items for $path\n";
	}
	my $invalidate_columns;
	my $changes;
	my $stats;
	my $glob = $self->_changes_path . '/*';
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
		} elsif ( my $code = $e->{code} ) {
			if ( $commit ) {
				my $commit_changed;
				my $t = time();
				foreach my $i ( 0 .. $#$items ) {
					MojoFacets::Data::__commit_path_code( $path, $i, $code, \$commit_changed );
				}
				$t = time() - $t;
				$self->stash( 'commit_changed', $commit_changed );
				warn "commit_changed in $t s ",dump( $e->{commit_changed}, $commit_changed );
				$e->{commit_changed_this} = $commit_changed;
				MojoFacets::Data::__invalidate_path_column( $path, $_ ) foreach keys %$commit_changed;
				MojoFacets::Data::__path_rebuild_stats( $path );
			}
			$stats->{code}++;
		} else {
			warn "no unique in ", dump($e);
			$stats->{no_unique}++;
		}
		push @$changes, $e;
	}

	foreach my $name ( keys %$invalidate_columns ) {
		MojoFacets::Data::__invalidate_path_column( $path, $name );
	}

	MojoFacets::Data::__path_modified( $path );

	my @loaded = MojoFacets::Data::__loaded_paths();
	warn "# loaded paths ",dump @loaded;

	$self->render( path => $path, changes => $changes, loaded => \@loaded, stats => $stats );
}

sub remove {
	my $self = shift;

	if ( my $t = $self->param('time') ) {
		unlink $self->_changes_path . '/' . $t;
	}

	$self->redirect_to('/changes');
}

1;
