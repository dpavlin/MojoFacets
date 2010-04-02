package MojoFacets::Data;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;
use JSON;
use Encode;

sub index {
	my $self = shift;

	my $path = $self->app->home->rel_dir('data');
	die "no data dir $path" unless -d $path;

	opendir(my $dir, $path) || die $!;
	my @files = 
		grep { -f "$path/$_" && $_ =~ m/\.js(on)?$/ }
		readdir $dir;
	close($dir);

	$self->render( files => [ @files ] );
}

our $data;
our $stats;

sub load {
	my $self = shift;

	my $path = $self->app->home->rel_file( 'data/' . $self->param('path') );
	die "$path $!" unless -r $path;

	$self->session('path' => $self->param('path'));

	# we could use Mojo::JSON here, but it's too slow
#	$data = from_json read_file $path;
	$data = read_file $path;
	Encode::_utf8_on($data);
	warn "# json snippet: ", substr($data,0,200);
	$data = from_json $data;

	$stats = {};

	foreach my $e ( @{ $data->{items} } ) {
		foreach my $n ( keys %$e ) {
			$stats->{$n}->{count}++;
			$stats->{$n}->{number}++
				if $e->{$n} =~ m/^[-+]?([0-9]*\.[0-9]+|[0-9]+)$/;
			$stats->{$n}->{array} += $#{ $e->{$n} } + 1
				if ref $e->{$n} eq 'ARRAY';
		}
	}

	foreach my $n ( keys %$stats ) {
		next unless defined $stats->{$n}->{array};
		delete $stats->{$n}->{array}
			if $stats->{$n}->{array} == $stats->{$n}->{count};
	}

	warn dump($stats);

	$self->redirect_to( '/data/columns' );
}


sub columns {
    my $self = shift;

    $self->render(
		message => 'Select columns to display',
		stats => $stats,
	);
}

sub _perm_array {
    my ($self,$name) = @_;

	my @array = $self->param($name);

	if ( @array ) {
		$self->session($name => [ @array ]);
	} else {
		@array = @{ $self->session($name) };
	}
	warn "# $name ",dump @array;
	return @array;
}

sub _perm_scalar {
    my ($self,$name,$default) = @_;

	my $scalar = $self->param($name);

	if ( defined $scalar ) {
		$self->session($name => $scalar);
	} else {
		$scalar = $self->session($name);
	}

	if ( ! defined $scalar ) {
		$scalar = $default;
		die "no default for $name" unless defined $scalar;
		$self->session($name => $scalar);
	}

	warn "# $name ",dump $scalar;
	return $scalar;
}

sub table {
    my $self = shift;

	$self->redirect_to('/data/index') unless $data->{items};

	my @columns = $self->_perm_array('columns');
	my $order   = $self->_perm_scalar('order', $columns[0]);
	my $offset  = $self->_perm_scalar('offset', 0);
	my $limit   = $self->_perm_scalar('limit', 20);

	my @sorted = sort {
		$a->{$order} cmp $b->{$order}
	} @{ $data->{items} };

	@sorted = splice @sorted, $offset, $limit;

#	warn "# sorted ", dump @sorted;

	warn "$order $offset $limit";

	$self->render(
		order => $order,
		offset => $offset,
		limit => $limit,
		sorted => [ @sorted ],
		columns => [ @columns ],
		rows => $#{ $data->{items} } + 1,
	);

}

sub facet {
	my $self = shift;

	my $facet;
	my $name = $self->param('name') || die "no name";

	foreach my $i ( @{ $data->{items} } ) {
		next unless exists $i->{$name};
		if ( ref $i->{$name} eq 'ARRAY' ) {
			$facet->{$_}++ foreach @{ $i->{$name} };
		} else {
			$facet->{ $i->{$name} }++;
		}
	}

#	warn "# facet $name ",dump $facet;

	$self->render( name => $name, facet => $facet )
}

1;
