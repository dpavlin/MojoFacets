package MojoFacets::Gnuplot;

use warnings;
use strict;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use Digest::MD5 qw(md5_hex);
use Text::Unaccent::PurePerl;

sub index {
	my $self = shift;

	my $columns = $self->session('columns') || return $self->redirect_to('/data/columns');
	my $path    = $self->session('path')    || return $self->redirect_to('/data/load');
	my $with    = $self->param('with') || 'points';

	my $hide_columns;
	if ( $self->param('gnuplot_hide') ) {
		$hide_columns->{$_}++ foreach $self->param('gnuplot_hide');
		warn "## hide_columns ", dump $hide_columns;
	}

#	my $name = join('.', 'items', map { my $n = unac_string($_); $n =~ s/\W+/_/g; $n } @$columns );
	my $name = MojoFacets::Data::__export_path_name( $path, 'items', @$columns );

	warn "# name $name\n";

	my $url = "/export/$path/$name";
	my $dir = $self->app->home->rel_file('public');

	if ( -e "$dir/$url" ) {

		my @plot;
		foreach ( 1 .. $#$columns ) {
			my $title = $columns->[$_];
			my $n = $_ + 1;
			push @plot, qq|"$dir/$url" using 1:$n title "$title" with $with| unless $hide_columns->{ $title };
		}

		my $g = qq|

set terminal png
set output '$dir/$url.png'

		|;

		if ( my $timefmt = $self->param('timefmt') ) {
			$g .= qq|

set xdata time
set timefmt "$timefmt"
set format x "$timefmt"

			|;
		}

#set xrange [ "2009-01-01":"2010-01-01" ]
#set yrange [ 0 : ]

		$g .= "\n\nplot " . join(',', @plot) . "\n";

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
