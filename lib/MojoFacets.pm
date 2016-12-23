package MojoFacets;

use strict;
use warnings;

our $VERSION = '0.0001';

use base 'Mojolicious';

use Data::Dump qw(dump);
use Storable;
use Time::HiRes qw(time);


sub save_action {
	my ($self) = @_;
#	warn "## before_dispatch req ",dump($tx->req->url, $tx->req->params);
	my $path = $self->req->url->path;
	if ( $path =~ m{/data/} ) {
		if ( my $params = $self->req->params ) {

			my $time = time();
			if ( my $time_travel = $params->param('time') ) {
				warn "# time-travel to $time_travel\n";
				$time = $time_travel;
			}

			my $actions_path = '/tmp/actions/';
			mkdir $actions_path unless -e $actions_path;
			$path =~ s{/}{.}g;
			$actions_path .= sprintf '%.4f%s', $time, $path;

			my $hash = $params->to_hash;
			if ( $hash ) {
				store $hash, $actions_path;
				warn "SAVE $actions_path ", -s $actions_path, " bytes params = ", dump($hash), $/;
			}
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

	$self->hook(
			after_dispatch => sub {
				my ($self) = @_;
				save_action( $self );
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
