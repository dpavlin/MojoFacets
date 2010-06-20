package MojoFacets::Code;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;

sub index {
	my $self = shift;

	$self->redirect_to('/data/columns') unless $self->session('columns');
	my $columns = { map { $_ => 1 } @{ $self->session('columns') } };

	my $dir = $self->app->home->rel_dir('public') . '/code';

	my $snippets;

	foreach my $full_path ( glob("$dir/*.pl") ) {
		my $path = $full_path;
		$path =~ s/^$dir\/*//;
		$path =~ s/\.pl$//;
		my ( $depends, $description ) = split(/\./,$path,2);

		my @deps = split(/,/,$depends);
		my $found = -1;
		$found += $columns->{$_} foreach @deps;
warn "# depends $depends $found $#deps\n";
		next unless $found == $#deps;

		$snippets->{$depends}->{$description} = read_file $full_path, binmode => ':utf8';
	}

	$self->render(
		snippets => $snippets,
	);
}

1;
