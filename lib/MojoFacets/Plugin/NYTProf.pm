package MojoFacets::Plugin::NYTProf;

use Devel::NYTProf;
use Time::HiRes ();

sub register {
	my ($self, $app) = @_;

	# Start timer
	$app->plugins->add_hook(
		before_dispatch => sub {
			my ($self, $c) = @_;
			return unless $ENV{PROFILE};
			my $id = Time::HiRes::gettimeofday();
			$c->stash('nytprof.id' => $id);
			my $path = "/tmp/nytprof.$id";
			DB::enable_profile($path);
		}
	);

	# End timer
	$app->plugins->add_hook(
		after_dispatch => sub {
			my ($self, $c) = @_;
			my $p = $ENV{PROFILE} || return;
			DB::disable_profile();
			return unless my $id = $c->stash('nytprof.id');
			my $duration = Time::HiRes::gettimeofday() - $id;
			if ( $duration > $p ) {
				my $path = "/tmp/nytprof.$id";
				my $new  = "/tmp/MojoFacets.profile-$id-$duration";
				rename $path, $new;
				warn "profile $new $duration ", -s $new, " bytes\n";
			} else {
				warn "profile $path $duration < $p unlink\n";
				unlink $path;
			}
		}
	);
}

1;
