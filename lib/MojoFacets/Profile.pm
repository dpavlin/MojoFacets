package MojoFacets::Profile;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Path;

sub index {
	my $self = shift;

	my $path = '/tmp/MojoFacets.profile.';

	if ( my $profile = $self->param('profile') ) {
warn "XXX profile $profile\n";
		my $dir = $self->app->home->rel_dir('public') . "/profile/$profile";
		mkpath $dir unless -d $dir;
		system "nytprofhtml --file $path$profile --out $dir";
		$self->redirect_to("/profile/$profile/index.html");
	}


	$self->render(
		profiles => [ map { s/^\Q$path\E//; $_ } glob "$path*" ],
	);
}

1
