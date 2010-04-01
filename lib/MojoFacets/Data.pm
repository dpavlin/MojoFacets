package MojoFacets::Data;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;
use JSON;

our $data;

sub _data {
	my $self = shift;

	# we could use Mojo::JSON here, but it's too slow
	$data ||= from_json read_file $self->app->home->rel_file( 'data/bibpsi.js' );
}


sub stats {
    my $self = shift;

	$self->_data;

	my $stats;

	foreach my $e ( @{ $data->{items} } ) {
		foreach my $n ( keys %$e ) {
			$stats->{column}->{$n}->{count}++;
			$stats->{column}->{$n}->{number}++ if $e->{$n} =~ m/[-+]?([0-9]*\.[0-9]+|[0-9]+)/;
		}
	}

	$self->app->log->debug( 'stats', dump($stats) );
    # Render template "example/welcome.html.ep" with message
    $self->render(
		message => 'Welcome to the Mojolicious Web Framework!',
		stats => $stats,
	);
}

1;
