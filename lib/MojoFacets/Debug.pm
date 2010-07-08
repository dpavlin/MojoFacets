package MojoFacets::Debug;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use Storable;

sub index {
	my $self = shift;

	$self->render(
		loaded => $MojoFacets::Data::loaded,
	);
}

sub _ref_size {
	my ( $self, $ref ) = @_;
	return unless ref($ref);
	open(my $fh, '|-', 'cat > /dev/null');
	Storable::store_fd $ref, $fh;
	tell($fh);
}

sub loaded {
	my $self = shift;

	my $path = $self->session('path');
	my $key  = $self->param('id');

	my $loaded = $MojoFacets::Data::loaded->{$path}->{$key} || die "no $path $key in loaded";

	$self->render(
		loaded => $loaded,
	);
}

1
