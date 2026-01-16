package MojoFacets;

use strict;
use warnings;

our $VERSION = '0.0001';

use Mojo::Base 'Mojolicious';

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

    # Controllers are in MojoFacets::*
    $self->routes->namespaces(['MojoFacets']);

    # Routes
    my $r = $self->routes;

    # Default route
    $r->get('/')->to('data#index')->name('index');

    # Data controller
    $r->any('/data/load')->to('data#load')->name('data_load');
    $r->any('/data/remove')->to('data#remove')->name('data_remove');
    $r->any('/data/save')->to('data#save')->name('data_save');
    $r->get('/data/columns/:id')->to('data#columns', id => 0)->name('data_columns');
    $r->post('/data/columns/:id')->to('data#columns', id => 0);
    $r->get('/data/items/:id')->to('data#items', id => 'table')->name('data_items');
    $r->get('/data/facet/:name')->to('data#facet')->name('data_facet');
    $r->get('/data/facet')->to('data#facet')->name('data_facet');
    $r->post('/data/filter')->to('data#filter')->name('data_filter');
    $r->get('/data/export/:id')->to('data#export', id => 0)->name('data_export');
    $r->any('/data/stats/:id')->to('data#stats', id => 0);
    $r->any('/data/lookup/:id')->to('data#lookup', id => 0);
    $r->any('/data/edit/:id')->to('data#edit', id => 0);
    $r->any('/data/reload/:id')->to('data#reload', id => 0);
    $r->any('/data/order/:id')->to('data#order', id => 0);

    # Explicit index route for data controller
    $r->get('/data/index')->to('data#index')->name('data_index');

    # Other controllers
    $r->any('/profile/remove/:id')->to('profile#remove', id => 0);
    $r->any('/profile/:id')->to('profile#index', id => 0)->name('profile_index');

    $r->any('/changes/remove/:id')->to('changes#remove', id => 0);
    $r->any('/changes/:id')->to('changes#index', id => 0)->name('changes_index');

    $r->any('/code/remove/:id')->to('code#remove', id => 0);
    $r->any('/code/:id')->to('code#index', id => 0)->name('code_index');

    $r->any('/config/:id')->to('config#index', id => 0)->name('config_index');

    $r->any('/actions/view/:id')->to('actions#view', id => 0);
    $r->any('/actions/:id')->to('actions#index', id => 0)->name('actions_index');

    $r->any('/gnuplot/:id')->to('gnuplot#index', id => 0)->name('gnuplot_index');

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
