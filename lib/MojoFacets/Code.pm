package MojoFacets::Code;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;

sub _code_dir { $_[0]->app->home->rel_file('public') . '/code' }

sub index {
	my $self = shift;

	return $self->redirect_to('/data/columns') unless $self->session('columns');
	my $columns = { map { $_ => 1 } @{ $self->session('columns') } };

	if ( $self->param('all_columns') ) {
		$columns->{$_} = 1 foreach @{ $self->session('header') }
	}

	my $dir = $self->_code_dir;

	my $snippets;
	my $no_deps;

	foreach my $full_path ( glob("$dir/*.pl") ) {
		my $path = $full_path;
		$path =~ s/^$dir\/*//;
		$path =~ s/\.pl$//;
		my ( $depends, $description ) = split(/\./,$path,2);

		my @deps = split(/,/,$depends);
		my $found = -1;
		$found += $columns->{$_} foreach @deps;
warn "# depends $depends $found $#deps\n";

		if ( $found != $#deps ) {
			$self->param('all_code') ? $no_deps->{$depends}->{$description}++ : next;
		}

		$snippets->{$depends}->{$description} = read_file $full_path, binmode => ':utf8';
	}

warn "# no_deps ",dump($no_deps);

	$self->render(
		snippets => $snippets,
		no_deps => $no_deps,
	);
}

sub remove {
	my $self = shift;
	if ( my $path = $self->param('path') ) {
		unlink $self->_code_dir . '/' . $path;
	}
	return $self->redirect_to('/code');
}

1;
