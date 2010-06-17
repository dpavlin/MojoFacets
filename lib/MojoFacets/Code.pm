package MojoFacets::Code;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;

sub index {
	my $self = shift;

	my $dir = $self->app->home->rel_dir('public') . '/code';

	my $snippets;

	foreach my $full_path ( glob("$dir/*.pl") ) {
		my $path = $full_path;
		$path =~ s/^$dir\/*//;
		my ( $column, $description ) = split(/\./,$path,2);
		$snippets->{$column}->{$description} = read_file $full_path;
	}

	$self->render(
		snippets => $snippets,
	);
}

1;
