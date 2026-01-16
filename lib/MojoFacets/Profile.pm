package MojoFacets::Profile;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Path;

sub index {
	my $self = shift;

	my $path = '/tmp/MojoFacets.profile.';

	if ( my $profile = $self->param('profile') ) {
warn "XXX profile $profile\n";
		my $dir = $self->app->home->child('public')->to_string . "/profile/$profile";
		if ( ! -e $dir ) {
			mkpath $dir unless -d $dir;
			system "nytprofhtml --file $path$profile --out $dir";
			$self->stash( 'nytprof.disabled' => 1 );
		}
		return $self->redirect_to("/profile/$profile/index.html");
	}


	$self->render(
		profiles => [ map { s/^\Q$path\E//; $_ } glob "$path*" ],
	);
}

sub remove {
	my $self = shift;

	if ( my $profile = $self->param('profile') ) {
		unlink "/tmp/MojoFacets.profile.$profile";
		rmtree $self->app->home->child('public')->to_string . "/profile/$profile";
	}

	return $self->redirect_to('/profile');
}

1
