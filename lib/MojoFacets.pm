package MojoFacets;

use strict;
use warnings;

our $VERSION = '0.0001';

use base 'Mojolicious';

use Data::Dump qw(dump);
use Storable;
use Time::HiRes qw(time);


sub save_tx {
	my ($self,$tx) = @_;
#	warn "## before_dispatch req ",dump($tx->req->url, $tx->req->params);
	my $parts = $tx->req->url->path->parts;
	warn "# parts ",dump( $parts );
	if ( $parts->[0] eq 'data' ) {
		if ( my $params = $tx->req->params ) {

			warn "# params ",dump($params);

			my $time = time();
			if ( my $time_travel = $params->param('time') ) {
				warn "# time-travel to $time_travel from ", $tx->remote_address;
				$time = $time_travel;
			}

			my $path = '/tmp/actions/';
			mkdir $path unless -e $path;
			$path .= sprintf '%.4f.%s', $time, join('.', @$parts);

			store $params, $path;
			warn "$path ", -s $path, " bytes\n";
		}
	}
}

# This method will run once at server start
sub startup {
    my $self = shift;

    # Routes
    my $r = $self->routes;

    # Default route
    $r->route('/:controller/:action/:id')->to('data#index', id => 0);

#	$self->plugin( 'request_timer' );

	$self->plugins->add_hook(
			before_dispatch => sub {
				my ($self, $c) = @_;
				my $tx = $c->tx;
				save_tx( $self, $tx );
			}
	);
	
	eval 'use MojoFacets::Plugin::NYTProf';
	if ( $@ ) {
		warn "profile disabled: ",substr($@,0,40) if $@;
	} else {
		MojoFacets::Plugin::NYTProf->register( $self );
	}
}



1;
