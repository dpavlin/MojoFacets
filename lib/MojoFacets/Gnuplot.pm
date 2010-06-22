package MojoFacets::Gnuplot;

use warnings;
use strict;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use Digest::MD5 qw(md5_hex);

sub index {
	my $self = shift;

	my $columns = $self->session('columns') || $self->redirect_to('/data/columns');

	my $url = '/export/' . $self->session('path') . '/' . join('.', @$columns);
	my $dir = $self->app->home->rel_dir('public');

	if ( -e "$dir/$url" ) {

		my @plot;
		foreach ( 1 .. $#$columns ) {
			my $n = $_ + 1;
			push @plot, qq|"$dir/$url" using 1:$n title "$columns->[$_]" with linespoints|;
		}

		my $g = qq|

set terminal png
set output '$dir/$url.png'

set xdata time
set timefmt "%Y-%m-%d"
#set format x "%d.%m."
#set format x "%Y-%m-%d"
#set xrange [ "2009-01-01":"2010-01-01" ]
#set yrange [ 0 : ]

plot | . join(',', @plot) . "\n";

warn "gnuplot $g";

		open(my $gnuplot, '|-', 'gnuplot') || die "gnuplot $!";
		print $gnuplot $g;
		close $gnuplot;

		$self->redirect_to( "$url.png" );
		#$self->render_text( "$url.png" );
	} else {
		$self->render_text("no graph for $url");
	}
}

1;
