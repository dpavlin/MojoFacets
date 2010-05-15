package MojoFacets::Data;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;
use JSON;
use Encode;
use locale;
use File::Find;

our $loaded;

sub index {
	my $self = shift;

	my $path = $self->app->home->rel_dir('data');
	die "no data dir $path" unless -d $path;

	my @files;
	find( sub {
		my $file = $File::Find::name;
		if ( -f $file && $file =~ m/\.(js(on)?|txt)$/ ) {
			$file =~ s/$path\/*//;
			push @files, $file;
		} else {
			warn "IGNORE: $file\n";
		}
	}, $path);

	@files = sort { lc $a cmp lc $b } @files;
	my $size;
	$size->{$_} = -s "$path/$_" foreach @files;

	$self->render(
		files => [ @files ],
		size => $size,
		loaded => $loaded,
	);
}

sub _load_path {
	my ( $self, $path ) = @_;

	return if defined $loaded->{$path}->{data};

	my $full_path = $self->app->home->rel_file( 'data/' . $path );
	die "$full_path $!" unless -r $full_path;

	# we could use Mojo::JSON here, but it's too slow
#	$data = from_json read_file $path;
	my $data = read_file $full_path;
	warn "# data snippet: ", substr($data,0,200);
	my @header;
	if ( $path =~ m/\.js/ ) {
		Encode::_utf8_on($data);
		$data = from_json $data;
	} elsif ( $path =~ m/\.txt/ ) {
		my @lines = split(/\r?\n/, $data);
		$data = { items => [] };

		my $header_line = shift @lines;
		my $multiline = $header_line =~ s/\^//g;
		@header = split(/\|/, $header_line );
		warn "# header ", dump( @header );
		while ( my $line = shift @lines ) {
			$line =~ s/\^//g;
			chomp $line;
			my @v = split(/\|/, $line);
			while ( @lines && $#v < $#header ) {
				$line = $lines[0];
				$line =~ s/\^//g;
				chomp $line;
				my @more_v = split(/\|/, $line);
				if ( $#v + $#more_v > $#header ) {
					warn "short line: ",dump( @v );
					last;
				}
				shift @lines;
				$v[ $#v ] .= shift @more_v;
				push @v, @more_v if @more_v;

				if ( $#v > $#header ) {
					die "# splice $#header ", dump( @v );
					@v = splice @v, 0, $#header;
				}
			}
			my $item;
			$item->{ $header[$_] || "f_$_" } = [ $v[$_] ] foreach ( 0 .. $#v );
			push @{ $data->{items} }, $item;
		}
	} else {
		warn "file format unknown $path";
	}

	my $stats;

	foreach my $e ( @{ $data->{items} } ) {
		foreach my $n ( keys %$e ) {
			$stats->{$n}->{count}++;
			if ( ref $e->{$n} eq 'ARRAY' ) {

				$stats->{$n}->{array} += $#{ $e->{$n} } + 1;

				foreach my $x ( @{$e->{$n}} ) {
					$stats->{$n}->{numeric}++
						if $x =~ m/^[-+]?([0-9]*\.[0-9]+|[0-9]+)$/;
				}

			} else {
				$stats->{$n}->{numeric}++
					if $e->{$n} =~ m/^[-+]?([0-9]*\.[0-9]+|[0-9]+)$/;
			}
		}
	}

	foreach my $n ( keys %$stats ) {
		next unless defined $stats->{$n}->{array};
		delete $stats->{$n}->{array}
			if $stats->{$n}->{array} == $stats->{$n}->{count};
	}

	@header =
		sort { $stats->{$b}->{count} <=> $stats->{$a}->{count} }
		grep { defined $stats->{$_}->{count} } keys %$stats
		unless @header;

	warn dump($stats);

	$loaded->{ $path } = {
		header => [ @header ],
		stats  => $stats,
		full_path => $full_path,
		size => -s $full_path,
		data => $data,
	};

}


sub load {
	my $self = shift;

	my @paths = $self->param('paths');
	warn "# paths ", dump @paths;
	$self->_load_path( $_ ) foreach @paths;

 	my $path = $self->param('path') || $self->redirect_to( '/data/index' );
	warn "# path $path\n";
	$self->session('path' => $path);
	$self->_load_path( $path );

	$self->session( 'header' => $loaded->{$path}->{header} );
	$self->session( 'columns' => $loaded->{$path}->{header} );

	$self->redirect_to( '/data/columns' );
}


sub _loaded {
	my ( $self, $name ) = @_;
	my $path = $self->session('path');
	die "$path $name doesn't exist in loaded ",dump( $loaded )
		unless defined $loaded->{$path}->{$name};
	return $loaded->{$path}->{$name};
}




sub columns {
    my $self = shift;

	my $stats = $self->_loaded( 'stats' ); # || $self->redirect_to( '/data/index' );

	my @columns;
	@columns = grep { defined $stats->{$_}->{count} } @{ $self->session('columns') } if $self->session('columns');

	foreach my $c ( @{ $self->session( 'header' ) } ) {
		push @columns, $c unless grep { /^\Q$c\E$/ } @columns;
	}

    $self->render(
		message => 'Select columns to display',
		stats => $stats,
		columns => \@columns,
		checked => $self->_checked( $self->_perm_array('columns') ),
	);
}

sub _perm_array {
    my ($self,$name) = @_;

	my @array = $self->param($name);

	if ( @array ) {
		$self->session($name => [ @array ]);
	} elsif ( my $session = $self->session($name) ) {
		if ( ref $session eq 'ARRAY' ) {
			@array = @$session;
		} else {
			die "$name not array ",dump($session);
		}
	}
	warn "# $name ",dump @array;
	return @array;
}

sub _perm_scalar {
    my ($self,$name,$default) = @_;

	my $scalar = $self->param($name);

	if ( defined $scalar ) {
		$self->session($name => $scalar);
	} else {
		$scalar = $self->session($name);
	}

	if ( ! defined $scalar ) {
		$scalar = $default;
		die "no default for $name" unless defined $scalar;
		$self->session($name => $scalar);
	}

	warn "# $name ",dump $scalar;
	return $scalar;
}

sub filter {
	my $self = shift;

	my $name = $self->param('filter_name') || die "name?";
	my @vals = $self->param('filter_vals');

	warn "# filter $name vals ",dump(@vals);

	my $path = $self->session('path');
	my $filters = $loaded->{$path}->{filters};
	if ( @vals ) {
		$filters->{$name} = [ @vals ];
	} else {
		delete $filters->{$name};
	}
	$loaded->{$path}->{filters} = $filters;

	warn "# filters ",dump($filters);

	$self->session( 'offset' => 0 );

	$self->redirect_to('/data/items');
}

sub _filter_item {
	my ( $self, $filters, $i ) = @_;
	my $pass = 1;
	foreach my $n ( keys %$filters ) {
		my @filter_values = @{ $filters->{$n} };
		my $include_missing = grep { /^_missing/ } @filter_values;
		if ( ! exists $i->{$n} ) {
			if ( $include_missing ) {
				$pass = 1;
				next;
			} else {
				$pass = 0;
				last;
			}
		}
		# and match any of values in element
		my $have_values = 0;
		foreach my $v ( @{ $i->{$n} } ) { # FIXME not array?
			$have_values ||= 1 if grep { m/^\Q$v\E$/ } @filter_values;
		}
		if ( ! $have_values ) {
			$pass = 0;
			last;
		}
	}
	return $pass;
}

sub _data_items {
	my $self = shift;
	my $path = $self->session('path') || $self->redirect_to( '/data/index' );
	my $all_filters = $loaded->{$path}->{filters};
	warn "# all_filters ",dump($all_filters);
	my $filters;
	$filters->{ $_ } = $all_filters->{ $_ }
		foreach (
			grep { defined $all_filters->{ $_ } }
			@{ $self->_loaded('header') }
		);
	warn "# filters ",dump($filters);
 	my $data = $self->_loaded( 'data' );
	grep {
		$filters ? $self->_filter_item( $filters, $_ ) : 1;
 	} @{ $data->{items} };
}

sub items {
    my $self = shift;

	$self->redirect_to('/data/index') unless defined $loaded->{ $self->session('path') };

	my @columns = $self->_perm_array('columns');
	$self->redirect_to('/data/columns') unless @columns;
	my $order   = $self->_perm_scalar('order', $columns[0]);
	my $sort    = $self->_perm_scalar('sort', 'a');
	my $offset  = $self->_perm_scalar('offset', 0);
	my $limit   = $self->_perm_scalar('limit', 20);
	$self->_perm_scalar('show', 'table');

	# fix offset when changing limit
	$offset = int( $offset / $limit ) * $limit;

	# FIXME - multi-level sort
	my $numeric = $self->_is_numeric($order);
	my $missing = $numeric ? 0 : '';
	no warnings qw(numeric);
	my @sorted = sort {
		my $v1 = exists $a->{$order} ? join('', @{$a->{$order}}) : $missing;
		my $v2 = exists $b->{$order} ? join('', @{$b->{$order}}) : $missing;
		($v1,$v2) = ($v2,$v1) if $sort eq 'd';
		$numeric ? $v1 <=> $v2 : $v1 cmp $v2 ;
	} $self->_data_items;

#	warn "# sorted ", dump @sorted;

	my $rows = $#sorted + 1;

	$self->render(
		order => $order,
		offset => $offset,
		limit => $limit,
		sorted => [ splice @sorted, $offset, $limit ],
		columns => [ @columns ],
		rows => $rows,
		numeric => { map { $_, $self->_is_numeric($_) } @columns },
	);

}


sub order {
	my $self = shift;
	$self->session('order', $self->param('order'));
	$self->session('sort', $self->param('sort'));
	$self->redirect_to('/data/items');
}

sub _is_numeric {
	my ( $self, $name ) = @_;

	my $stats = $self->_loaded( 'stats' );

	# sort facet numerically if more >50% elements are numeric
	defined $stats->{$name}->{numeric} &&
		$stats->{$name}->{numeric} > $stats->{$name}->{count} / 2;
}

sub facet {
	my $self = shift;

	my $path = $self->session('path') || $self->redirect_to( '/data/index' );

	if ( my $remove = $self->param('remove') ) {
		delete $loaded->{$path}->{filters}->{$remove};
		$self->redirect_to( '/data/items' );
	}

	my $facet;
	my $name = $self->param('name') || die "no name";

	foreach my $i ( $self->_data_items ) {
		if ( ! exists $i->{$name} ) {
			$facet->{ _missing }++;
		} elsif ( ref $i->{$name} eq 'ARRAY' ) {
			$facet->{$_}++ foreach @{ $i->{$name} };
		} else {
			$facet->{ $i->{$name} }++;
		}
	}

#	warn "# facet $name ",dump $facet;

	my $checked;
	if ( my $f = $loaded->{$path}->{filters} ) {
		if ( defined $f->{$name} ) {
			$checked = $self->_checked( @{ $f->{$name} } );
		}
	}

	my $sort = $self->param('sort') || 'c';

	# sort facet numerically if more >50% elements are numeric
	my $numeric = $self->_is_numeric($name);

	my @facet_names = sort {
		if ( $sort =~ m/a/i ) {
			$numeric ? $a <=> $b : lc $a cmp lc $b;
		} elsif ( $sort =~ m/d/i ) {
			$numeric ? $b <=> $a : lc $b cmp lc $a;
		} elsif ( $sort =~ m/c/i ) {
			$facet->{$b} <=> $facet->{$a};
		} else {
			warn "unknown sort: $sort";
			$a cmp $b;
		}
	} keys %$facet;

	$self->render( name => $name, facet => $facet, checked => $checked,
		facet_names => \@facet_names, sort => $sort, numeric => $numeric,
	);
}

sub _checked {
	my $self = shift;
	my $checked;
	$checked->{$_}++ foreach @_;
	warn "# _checked ",dump($checked);
	return $checked;
}

1;
