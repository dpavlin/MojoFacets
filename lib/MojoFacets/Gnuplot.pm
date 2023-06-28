package MojoFacets::Gnuplot;

use warnings;
use strict;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use Digest::MD5 qw(md5_hex);
use Text::Unaccent::PurePerl;
use MojoFacets::Data;

sub index {
	my $self = shift;

	my $columns = $self->session('columns') || return $self->redirect_to('/data/columns');
	my $path    = $self->session('path')    || return $self->redirect_to('/data/load');
	my $with    = $self->param('with') || 'points';

	my $gnuplot_hide = $self->every_param('gnuplot_hide');
	warn "## gnuplot_hide=",dump( $gnuplot_hide );
	my $hide_columns;
	$hide_columns->{$_}++ foreach @$gnuplot_hide;
	warn "## hide_columns ", dump $hide_columns;

#	my $name = join('.', 'items', map { my $n = unac_string($_); $n =~ s/\W+/_/g; $n } @$columns );
	my $name = MojoFacets::Data::__export_path_name( $path, 'items', @$columns );

	warn "# name $name\n";

	my $url = "/export/$path/$name";
	my $dir = $self->app->home->rel_file('public');

	if ( -e "$dir/$url" ) {

		my $timefmt = $self->param('timefmt');

		my $timefmt_x = $timefmt;
		$timefmt_x =~ s/[ T]%H/\\n%H/; # wrap to two lines
		$timefmt_x =~ s/%Y/%y/; # short year

		my $spaces = $timefmt;
		$spaces =~ s/\S+//g;
warn "# spaces: [$spaces]",dump( $spaces );
		$spaces = length( $spaces );
warn "# spaces: $spaces";

		my @plot;
		foreach ( 1 .. $#$columns ) {
			my $title = $columns->[$_];
			next if $hide_columns->{$title};
			$title =~ s/_/ /g;
 			next if $hide_columns->{ $title };

			my $n = $_ + 1 + $spaces;
			push @plot, qq|"$dir/$url" using 1:$n notitle with $with lc $_ pt 7 ps 0.5|, # pt 7 - circle, ps 2 - size 2
						qq|NaN lc $_ title "$title" with lines|
			;
		}

		my $g = qq|

set terminal png size 1000,400
set output '$dir/$url.png'

		|;

		if ( $timefmt ) {
			$g .= qq|

set xdata time
set timefmt "$timefmt"
#set format x "$timefmt"
set format x "$timefmt_x"

			|;
		}

#set xrange [ "2009-01-01":"2010-01-01" ]
#set yrange [ 0 : ]

		$g .= "\n\nplot " . join(',', @plot) . "\n";
		$g =~ s/\n\n+/\n/sg;

warn "gnuplot $g";

		open(my $gnuplot, '|-', 'gnuplot') || die "gnuplot $!";
		print $gnuplot $g;
		close $gnuplot;

		if ( -e "$dir/$url.png" ) {
			warn "redirect $url.png";
			return $self->redirect_to( "$url.png" );
		} else {
			$self->render_text( "no $dir/$url.png" );
		}
	} else {
		$self->render_text("no graph for $url");
	}
}

1;
