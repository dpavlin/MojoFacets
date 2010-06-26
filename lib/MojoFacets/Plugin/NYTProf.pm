package MojoFacets::Plugin::NYTProf;

use Devel::NYTProf;
use Time::HiRes ();

sub register {
	my ($self, $app) = @_;

	# Start timer
	$app->plugins->add_hook(
		before_dispatch => sub {
			my ($self, $c) = @_;
			my $id = Time::HiRes::gettimeofday();
			$c->stash('nytprof.id' => $id);
			my $path = "/tmp/nytprof.$id";
			DB::enable_profile($path);
			warn "profile $path started\n";
		}
	);

	# End timer
	$app->plugins->add_hook(
		after_dispatch => sub {
			my ($self, $c) = @_;
			DB::disable_profile();
			return unless my $id = $c->stash('nytprof.id');
			my $path = "/tmp/nytprof.$id";
			warn "profile $path ", -s $profile, " bytes\n";
		}
	);
}

1;
