package MojoFacets;

use strict;
use warnings;

our $VERSION = '0.0001';

use base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Routes
    my $r = $self->routes;

    # Default route
    $r->route('/:controller/:action/:id')->to('data#stats', id => 1);
}

1;
