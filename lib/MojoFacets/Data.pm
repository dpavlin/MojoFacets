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
our $filters;

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
		filters => $filters,
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
				$v[ $#v ] .= shift @more_v if @more_v;
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
			my @v;
			if ( ref $e->{$n} eq 'ARRAY' ) {
				$stats->{$n}->{array} += $#{ $e->{$n} } + 1;
				@v = @{ $e->{$n} };
			} else {
				@v = ( $e->{$n} );
			}

			foreach my $x ( @v ) {
				$stats->{$n}->{numeric}++
					if $x =~ m/^[-+]?([0-9]*\.[0-9]+|[0-9]+)$/;
				$stats->{$n}->{empty}++
					if $x =~ m/^\s*$/;
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
	if ( ! defined $loaded->{$path}->{columns} ) {
		$self->session( 'columns' => $loaded->{$path}->{header} );
		$self->redirect_to( '/data/columns' );
	} else {
		$self->session( 'columns' => $loaded->{$path}->{columns} );
		$self->redirect_to( '/data/items' );
	}
		
}


sub _loaded {
	my ( $self, $name ) = @_;
	my $path = $self->session('path');
	die "$path $name doesn't exist in loaded ",dump( $loaded )
		unless defined $loaded->{$path}->{$name};
	return $loaded->{$path}->{$name};
}


sub _checked {
	my $self = shift;
	my $checked;
	$checked->{$_}++ foreach @_;
#	warn "# _checked ",dump($checked);
	return $checked;
}


sub columns {
    my $self = shift;

	if ( $self->param('columns') ) {
		$self->_perm_array('columns');
		$self->redirect_to('/data/items');
	}

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
	my $path  = $self->session('path');

	if ( @array ) {
		$self->session($name => [ @array ]);
		$loaded->{$path}->{$name} = [ @array ];
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

	warn "# _perm_scalar $name ",dump $scalar;
	return $scalar;
}

sub filter {
	my $self = shift;

	my $name = $self->param('filter_name') || die "name?";
	my @vals = $self->param('filter_vals');

#	warn "# filter $name vals ",dump(@vals);

	my $path = $self->session('path');

	if ( @vals ) {
		$filters->{$name} = [ @vals ];
		warn "# filter + $name $#vals\n";

		my $filter_hash;
		$filter_hash->{$_}++ foreach @vals;

		warn "# filter_hash ",dump( $filter_hash );

		my $items = $self->_loaded('data')->{items};

		my $include_missing = defined $filter_hash->{_missing};
		my $filtered_items;

		foreach my $i ( 0 .. $#$items ) {

			if ( defined $items->[$i]->{$name} ) {
				foreach my $v ( @{ $items->[$i]->{$name} } ) {
					if ( defined $filter_hash->{ $v } ) {
						$filtered_items->{$i}++;
					}
				}
			} elsif ( $include_missing ) {
				$filtered_items->{$i}++;
			}
		}

		warn "# filter $name ",dump($filtered_items);

		$loaded->{$path}->{filters}->{$name} = $filtered_items;

	} else {
		warn "# filter - $name\n";
		delete $filters->{$name};
		delete $loaded->{$path}->{filters}->{$name};
	}

	warn "# filters ",dump($filters);

	$self->session( 'offset' => 0 );

	$self->redirect_to('/data/items');
}


sub _data_items {
	my ( $self, $all ) = @_;
 	my $data = $self->_loaded( 'data' );

	return @{ $data->{items} } if $all == 1;

	my $filters = $self->_current_filters;
	my $filter_value;
	foreach my $f ( keys %$filters ) {
		foreach my $n ( @{ $filters->{$f} } ) {
			$filter_value->{$f}->{$n} = 1;
		}
	}
 	my @items = @{ $data->{items} };
	@items = grep {
		my $i = $_;
		my $pass = 1;
		foreach my $n ( keys %$filter_value ) {
			if ( ! exists $i->{$n} ) {
				if ( defined $filter_value->{$n}->{_missing} ) {
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
				$have_values ||= 1 if defined $filter_value->{$n}->{$v};
			}
			if ( ! $have_values ) {
				$pass = 0;
				last;
			}
		}
		$pass;
	} @items if $filter_value;
	return @items;
}


sub _current_filters {
	my $self = shift;
	my $current_filters;
	$current_filters->{ $_ } = $filters->{ $_ }
		foreach (
			grep { defined $filters->{ $_ } }
			@{ $self->_loaded('header') }
		);
	warn "# current_filters ",dump($current_filters);
	return $current_filters;
}

sub _data_sorted_by {
	my ( $self, $order ) = @_;

	my $path = $self->session('path');

	if ( defined $loaded->{$path}->{sorted}->{$order} ) {
		return $loaded->{$path}->{sorted}->{$order};
	}

 	my $data = $self->_loaded( 'data' );
	my $numeric = $self->_is_numeric($order);
	my $missing = $numeric ? 0 : '';
	no warnings qw(numeric);
	my $nr = 0;
	my @sorted = map {
		$_->[0]
	} sort {
		if ( $numeric ) {
			$a->[1] <=> $b->[1]
		} else {
			$a->[1] cmp $b->[1]
		}
	} map {
		[ $nr++, exists $_->{$order} ? join('', @{$_->{$order}}) : $missing ]
	} @{ $data->{items} }
	;

	warn "sorted $order"; # ,dump( @sorted );

	$loaded->{$path}->{sorted}->{$order} = [ @sorted ];
}


sub items {
	my $self = shift;

	my $path = $self->session('path');
	$self->redirect_to('/data/index') unless defined $loaded->{ $path };

	my @columns = $self->_perm_array('columns');
	$self->redirect_to('/data/columns') unless @columns;
	my $order   = $self->_perm_scalar('order', $columns[0]);
	my $sort    = $self->_perm_scalar('sort', 'a');
	my $offset  = $self->_perm_scalar('offset', 0);
	my $limit   = $self->_perm_scalar('limit', 20);
	$self->_perm_scalar('show', 'table');

	# fix offset when changing limit
	$offset = int( $offset / $limit ) * $limit;

	my $sorted = $self->_data_sorted_by( $order );

	my $path_filters = $loaded->{$path}->{filters};
	my @filter_names = keys %$path_filters;

	my @filtered;
	foreach my $i ( 0 .. $#$sorted ) {
		my $pos = $sort eq 'd' ? $sorted->[$i] : $sorted->[ $#$sorted - $i ];

		my $skip = 0;
		foreach ( @filter_names ) {
			$skip ||= 1 if ! defined $path_filters->{$_}->{$pos};
		}
		next if $skip;

		push @filtered, $pos;
	}

	my $sorted_items;
	my $data = $self->_loaded('data');
	foreach ( $offset .. $offset + $limit ) {
		last unless defined $filtered[$_];
		push @$sorted_items, $data->{items}->[ $filtered[$_] ];
	}


#	warn "# sorted ", dump $sorted;

	$self->render(
		order => $order,
		offset => $offset,
		limit => $limit,
		sorted => $sorted_items,
		columns => [ @columns ],
		rows => $#filtered + 1,
		numeric => { map { $_, $self->_is_numeric($_) } @columns },
		filters => $self->_current_filters,
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
	my $count = $stats->{$name}->{count};
	$count   -= $stats->{$name}->{empty} if defined $stats->{$name}->{empty};
	defined $stats->{$name}->{numeric} &&
		$stats->{$name}->{numeric} > $count / 2;
}

sub facet {
	my $self = shift;

	my $path = $self->session('path') || $self->redirect_to( '/data/index' );

	if ( my $remove = $self->param('remove') ) {
		delete $filters->{$remove};
		$self->redirect_to( '/data/items' );
	}

	my $facet;
	my $name = $self->param('name') || die "no name";

	my $all = $self->_perm_scalar('all', 1);

	foreach my $i ( $self->_data_items($all) ) {
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
	my @facet_names =
		  $all                      ? keys %$facet
		: defined $filters->{$name} ? @{ $filters->{$name} }
		: keys %$facet;

	$checked = $self->_checked( @{ $filters->{$name} } ) if defined $filters->{$name};

	my $sort = $self->param('sort') || 'c';

	# sort facet numerically if more >50% elements are numeric
	my $numeric = $self->_is_numeric($name);

	@facet_names = sort {
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
	} @facet_names;

	$self->render( name => $name, facet => $facet, checked => $checked,
		facet_names => \@facet_names, sort => $sort, numeric => $numeric,
	);
}

sub edit {
	my $self = shift;
	my $content = $self->param('content');

	$self->render(
		content => $content
	);
}

1;
