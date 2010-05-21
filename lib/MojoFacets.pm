package MojoFacets;

use strict;
use warnings;

our $VERSION = '0.0001';

use base 'Mojolicious';

use Data::Dump qw(dump);

# This method will run once at server start
sub startup {
    my $self = shift;

    # Routes
    my $r = $self->routes;

    # Default route
    $r->route('/:controller/:action/:id')->to('data#index', id => 1);

#	$self->plugin( 'request_timer' );

	$self->plugins->add_hook(
			before_dispatch => sub {
				my ($self, $c) = @_;
				my $tx = $c->tx;
				# Do whatever you want with the transaction here
				if ( $tx->req->url->query ) {
					warn "# before_dispatch url ",dump($tx->req->url);
				}
			}
	);
}

1;
