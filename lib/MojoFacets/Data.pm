package MojoFacets::Data;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;
use JSON;

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

	# we could use Mojo::JSON here, but it's too slow
	$data = from_json read_file $path;

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

sub table {
    my $self = shift;

	$self->redirect_to('/data/index') unless $data->{items};

	my @columns = $self->param('columns');

	my $order  = $self->param('order') || $columns[0];
	my $offset = $self->param('offset') || 0;
	my $limit  = $self->param('limit') || 10;

	my @sorted = sort {
		$a->{$order} cmp $b->{$order}
	} @{ $data->{items} };

	@sorted = splice @sorted, $offset, $limit;

	warn "# sorted ", dump @sorted;

	warn "$order $offset $limit";

	$self->render(
		order => $order,
		offset => $offset,
		limit => $limit,
		sorted => [ @sorted ],
		columns => [ @columns ],
	);

}

1;
