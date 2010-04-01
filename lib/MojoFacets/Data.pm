package MojoFacets::Example;

use strict;
use warnings;

use base 'Mojolicious::Controller';

our $data;

sub _data {
	my $self = shift;
	my $json = Mojo::JSON->new;

	$data ||= $json->decode(  File::Spec->catfile( $self->root, 'data', 'bibpsi.js' ) );
}


sub stats {
    my $self = shift;

	$self->_data;

	foreach my $e ( @{ $data->{items} } ) {
		foreach my $n ( keys %$e ) {
			$stats->{column}->{$n}->{count}++;
			$stats->{column}->{$n}->{number}++ if $e->{$n} =~ m/[-+]?([0-9]*\.[0-9]+|[0-9]+)/;
		}
	}
	warn "# stats ", $self->Dumper( $stats );
    # Render template "example/welcome.html.ep" with message
    $self->render(
		message => 'Welcome to the Mojolicious Web Framework!',
		stats => $stats,
	);
}

1;
