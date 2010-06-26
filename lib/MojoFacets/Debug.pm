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

1
