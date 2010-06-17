package MojoFacets::Data;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use Data::Dump qw(dump);
use File::Slurp;
use Encode;
use locale;
use File::Find;
use Storable;
use Time::HiRes qw(time);
use File::Path qw(mkpath);

use MojoFacets::Import::File;
use MojoFacets::Import::HTMLTable;

our $loaded;
our $filters;

sub index {
	my $self = shift;

	my $data_dir = $self->app->home->rel_dir('data');
	die "no data dir $data_dir" unless -d $data_dir;

	my @files;
	my $changes;
	find( sub {
		my $file = $File::Find::name;
		if ( -f $file && $file =~ m/\.(js(on)?|txt)$/ ) {
			$file =~ s/$data_dir\/*//;
			push @files, $file;
		} elsif ( -f $file && $file =~ m/([^\/]+)\.changes\/(\d+\.\d+.+)/ ) {
			push @{ $changes->{$1} }, $2
		} elsif ( -d $file && $file =~ m/\.html$/ ) {
			$file =~ s/$data_dir\/*//;
			push @files, $file;
		} else {
			warn "IGNORE: $file\n";
		}
	}, $data_dir);

	@files = sort { lc $a cmp lc $b } @files;
	my $size;
	$size->{$_} = -s "$data_dir/$_" foreach @files;

	$self->render(
		files => [ @files ],
		size => $size,
		loaded => $loaded,
		filters => $filters,
		dump_path => { map { $_ => $self->_dump_path($_) } @files },
		changes => $changes,
	);
}

sub _dump_path {
	my ( $self, $name ) = @_;
	my $dir = $self->app->home->rel_dir('data');
	$name =~ s/^$dir//;
	$name =~ s/\/+/_/g;
	return '/tmp/mojo_facets.' . $name . '.storable';
}

sub _save {
	my ( $self, $path ) = @_;

	my $dump_path = $self->_dump_path( $path );
	my $first_load = ! -e $dump_path;
	warn "save loaded to $dump_path";
	my $info = $loaded->{$path};
	store $info, $dump_path;

	if ( $first_load ) {
		my $mtime = $loaded->{$path}->{mtime};
		utime $mtime, $mtime, $dump_path;
		warn "sync time to $path at $mtime\n";
	}

	warn $dump_path, ' ', -s $dump_path, " bytes\n";
	return $dump_path;
}


sub __stats {

	my $stats;

	my $nr_items = $#{ $_[0] } + 1;

	warn "__stats $nr_items\n";

	foreach my $e ( @{ $_[0] } ) {
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
					if length $x == 0; # faster than $x =~ m/^\s*$/;
			}

		}
	}

	foreach my $n ( keys %$stats ) {
		my $s = $stats->{$n};
		next unless defined $s->{array};
		if ( $s->{array} == $s->{count} ) {
			delete $s->{array};
			if ( $s->{count} == $nr_items ) {
				warn "check $n for uniqeness\n";
				my $unique;
				foreach my $e ( @{ $_[0] } ) {
					if ( ++$unique->{ $e->{$n}->[0] } == 2 ) {
						$unique = 0;
						last;
					}
				}
				if ( $unique ) {
					$stats->{$n}->{unique} = 1;
					#warn "# $n unique ",dump( $unique );
				}
			}
		}
	}

	warn "# __stats ",dump($stats);

	return $stats;
}

sub _param_or_session {
	$_[0]->param( $_[1] ) || $_[0]->session( $_[1] )
}

sub stats {
	my $self = shift;
	my $path = $self->_param_or_session('path');
	warn "stats $path\n";
	delete $loaded->{$path}->{stats};
	$self->redirect_to( '/data/columns' );
}


sub _load_path {
	my ( $self, $path ) = @_;

	my $full_path = $self->app->home->rel_file( 'data/' . $path );
	die "$full_path $!" unless -r $full_path;

	my $dump_path = $self->_dump_path( $path );

	if ( defined $loaded->{$path}->{data} ) {
		my $mtime = (stat($full_path))[9];
		return if $loaded->{$path}->{mtime} == $mtime;
		warn "reload $full_path, modified ", time() - $mtime, " seconds ago\n";
	} elsif ( -e $dump_path ) {
		warn "dump_path $dump_path ", -s $dump_path, " bytes loading...\n";
		my $info = retrieve $dump_path;
		$loaded->{ $path } = $info;
		return;
	}

	my $data;
	if ( -f $full_path ) {
		$data = MojoFacets::Import::File->new( full_path => $full_path, path => $path )->data;
	} elsif ( -d $full_path && $full_path =~ m/.html/ ) {
		$data = MojoFacets::Import::HTMLTable->new( dir => $full_path )->data;
	} else {
		die "can't load $full_path";
	}

	my @header;

	if ( defined $data->{header} ) {
		if ( ref $data->{header} eq 'ARRAY' ) {
			@header = @{ $data->{header} };
		} else {
			warn "header not array ", dump( $data->{header} );
		}
	}

	my $stats = __stats( $data->{items} );

	@header =
		sort { $stats->{$b}->{count} <=> $stats->{$a}->{count} }
		grep { defined $stats->{$_}->{count} } keys %$stats
		unless @header;

	my $info = {
		header => [ @header ],
		stats  => $stats,
		full_path => $full_path,
		size => -s $full_path,
		mtime => (stat($full_path))[9],
		data => $data,
	};

	$loaded->{ $path } = $info;
	$self->_save( $path );

}


sub load {
	my $self = shift;

	my @paths = $self->param('paths');
	warn "# paths ", dump @paths;
	$self->_load_path( $_ ) foreach @paths;

 	my $path = $self->param('path') || $self->redirect_to( '/data/index' );
	warn "# path $path\n";
	$self->_load_path( $path );

	$self->session( 'path' => $path );

	my $redirect_to = '/data/items';

	$self->session( 'header' => $loaded->{$path}->{header} );
	if ( ! defined $loaded->{$path}->{columns} ) {
		my $columns_path = $self->_permanent_path( 'columns' );
		if ( -e $columns_path ) {
			my @columns = map { s/[\r\n]+$//; $_ } read_file $columns_path;
			$loaded->{$path}->{columns} = [ @columns ];
			warn "# columns_path $columns_path ",dump(@columns);
		} else {
			$loaded->{$path}->{columns} = $loaded->{$path}->{header}
		}

		$redirect_to = '/data/columns';
	}
	$self->session( 'columns' => $loaded->{$path}->{columns} );
	$self->session( 'order'   => $loaded->{$path}->{columns}->[0] );
	$self->redirect_to( $redirect_to );
}


sub _loaded {
	my ( $self, $name ) = @_;
	my $path = $self->session('path') || $self->param('path');
	$self->redirect_to('/data/index') unless $path;

	if ( defined $loaded->{$path}->{modified} && $loaded->{$path}->{modified} > 1 ) {
		my $caller = (caller(1))[3];
		if ( $caller =~ m/::edit/ ) {
			warn "rebuild stats for $path ignored caller $caller\n";
		} else {
			warn "rebuild stats for $path FORCED by modified caller $caller\n";
			$loaded->{$path}->{stats} = __stats( $loaded->{$path}->{data}->{items} );
			$loaded->{$path}->{modified} = 1;
		}
	}

	if ( ! defined $loaded->{$path}->{$name} ) {
		warn "$path $name isn't loaded\n";
		$self->_load_path( $path );
		if ( ! defined $loaded->{$path}->{stats} ) {
			warn "rebuild stats for $path\n";
			$loaded->{$path}->{stats} = __stats( $loaded->{$path}->{data}->{items} );
		}
		if ( ! defined $loaded->{$path}->{$name} ) {
			warn "MISSING $name for $path\n";
			$self->redirect_to('/data/index')
		}
	}

	$self->session( 'modified' => $loaded->{$path}->{modified} );

	return $loaded->{$path}->{$name};
}


sub _checked {
	my $self = shift;
	my $checked;
	$checked->{$_}++ foreach @_;
#	warn "# _checked ",dump($checked);
	return $checked;
}

sub _permanent_path {
	my $self = shift;
	my $path = $self->_param_or_session('path');
	$self->app->home->rel_dir('data') . '/' . join('.', $path, @_);
}

sub _export_path {
	my $self = shift;
	my $path = $self->_param_or_session('path');
	if ( ! $path ) {
		warn "no path in param or session";
		return;
	}
	my $dir = $self->app->home->rel_dir('public') . "/export/$path";
	mkpath $dir unless -e $dir;
	$dir . '/' . join('.', @_);
}

sub columns {
    my $self = shift;

	if ( $self->param('columns') ) {
		my @columns = $self->_param_array('columns');
		write_file( $self->_permanent_path( 'columns' ), map { "$_\n" } @columns );
		$self->redirect_to('/data/items');
	}

	my $stats = $self->_loaded( 'stats' );

	my @columns;
	@columns = grep { defined $stats->{$_}->{count} } @{ $self->session('columns') } if $self->session('columns');

	foreach my $c ( @{ $self->session( 'header' ) } ) {
		push @columns, $c unless grep { /^\Q$c\E$/ } @columns;
	}

    $self->render(
		message => 'Select columns to display',
		stats => $stats,
		columns => \@columns,
		checked => $self->_checked( $self->_param_array('columns') ),
	);
}

sub _param_array {
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
	#warn "# $name ",dump @array;
	return @array;
}

sub _param_scalar {
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

	$self->_remove_filter( $name );
	if ( @vals ) {
		$self->_filter_on_data( $name, @vals );
		if ( my $permanent = $self->param('_permanent') ) {
			my $permanent_path = $self->_export_path( 'filter', $name, $permanent );
			write_file $permanent_path, map { "$_\n" } @vals;
			warn "permanent filter $permanent_path ", -s $permanent_path;
		}
	}

	$self->session( 'offset' => 0 );

	$self->redirect_to('/data/items');
}

sub _filter_on_data {
	my ( $self, $name, @vals ) = @_;

	my $path = $self->session('path');

	if ( ! defined $loaded->{$path}->{stats}->{ $name } ) {
		warn "filter $name not found in data set";
		return;
	}

	$filters->{$name} = [ @vals ];
	warn "_filter_on_data $name ", $#vals + 1, " values on $path\n";

	my $filter_hash;
	$filter_hash->{$_}++ foreach @vals;

	#warn "# filter_hash ",dump( $filter_hash );

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

	#warn "# filter $name ",dump($filtered_items);

	$loaded->{$path}->{filters}->{$name} = $filtered_items;
	warn "filter $name with ", scalar keys %$filtered_items, " items created\n";
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
	#warn "# current_filters ",dump($current_filters);
	return $current_filters;
}

sub _data_sorted_by {
	my ( $self, $order ) = @_;

	my $path = $self->session('path');

	warn "_data_sorted_by $order from $path";

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
	} grep { ref $_->{$order} eq 'ARRAY' } @{ $data->{items} }
	;

	warn "sorted: $order numeric: $numeric items: ", $#sorted + 1, "\n";
	#warn "# sorted ",dump( @sorted );

	$loaded->{$path}->{sorted}->{$order} = [ @sorted ];
}


sub items {
	my $self = shift;

	if ( my $show = $self->param('id') ) {
		$self->param('show', $show);
		warn "show $show\n";
	}

	my $path = $self->session('path');

	my @columns = $self->_param_array('columns');
	$self->redirect_to('/data/columns') unless @columns;
	my $order   = $self->_param_scalar('order', $columns[0]);
	my $sort    = $self->_param_scalar('sort', 'a');
	my $offset  = $self->_param_scalar('offset', 0);
	my $limit   = $self->_param_scalar('limit', 20);
	$self->_param_scalar('show', 'table');

	# fix offset when changing limit
	$offset = int( $offset / $limit ) * $limit;

	my $sorted = $self->_data_sorted_by( $order );

	my @filter_names;
	if ( $filters ) {
		foreach my $name ( keys %$filters ) {
			if ( ! defined $loaded->{$path}->{stats}->{ $name } ) {
				warn "skip filter $name not found in $path\n";
				next;
			}
			push @filter_names, $name;
		}
		warn "filter_names ",dump( @filter_names );
		foreach my $name ( @filter_names ) {
			next if ref $loaded->{$path}->{filters}->{$name} eq 'ARRAY';
			$self->_filter_on_data( $name, @{ $filters->{$name} } );
		}
	}

	my $all_filters = join(' ',sort @filter_names,'order:',$order);

#	warn "# all_filters $all_filters ", dump( $loaded->{$path}->{filtered}->{$all_filters} );

	if ( ! defined $loaded->{$path}->{filtered}->{$all_filters} ) {

		my $path_filters = $loaded->{$path}->{filters};

		warn "create combined filter for $all_filters\n";

		my @filtered;
		foreach my $i ( 0 .. $#$sorted ) {
			my $pos = $sorted->[$i];

			if ( $#filter_names == -1 ) {
				push @filtered, $pos;
				next;
			}

			my $skip = 0;
			foreach ( @filter_names ) {
				$skip ||= 1 if ! defined $path_filters->{$_}->{$pos};
			}
			next if $skip;

			push @filtered, $pos;
		}

		$loaded->{$path}->{filtered}->{$all_filters} = [ @filtered ];
	}

	my $filtered = $loaded->{$path}->{filtered}->{$all_filters}
		if defined $loaded->{$path}->{filtered}->{$all_filters};

	warn "all_filters $all_filters produced ", $#$filtered + 1, " items\n" if $filtered;

	my $sorted_items;
	my $data = $self->_loaded('data');
	my $from_end = $sort eq 'd' ? $#$filtered : 0;
	foreach ( 0 .. $limit ) {
		my $i = $_ + $offset;
		last unless defined $filtered->[$i];
		$i = $from_end - $i if $from_end;
		my $id = $filtered->[$i];
		push @$sorted_items,
		my $item = $data->{items}->[ $id ];
		$item->{_row_id} ||= $id;
	}

	warn "# sorted_items ", $#$sorted_items + 1, " offset $offset limit $limit order $sort";

	$self->render(
		order => $order,
		offset => $offset,
		limit => $limit,
		sorted => $sorted_items,
		columns => [ @columns ],
		rows => $#$filtered + 1,
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

sub _remove_filter {
	my ($self,$name) = @_;
	warn "_remove_filter $name\n";

	my $path = $self->session('path');

	delete $filters->{$name};
	delete $loaded->{$path}->{filters}->{$name};
	warn "filters left: ", keys %{ $loaded->{$path}->{filters} };

	foreach (
			grep { /\b$name\b/ }
			keys %{ $loaded->{$path}->{filtered} }
	) {
		delete $loaded->{$path}->{filtered}->{$_};
		warn "remove filtered cache $_";
	}
}

sub facet {
	my $self = shift;

	my $path = $self->session('path') || $self->redirect_to( '/data/index' );

	if ( my $name = $self->param('remove') ) {
		$self->_remove_filter( $name );
		$self->redirect_to( '/data/items' );
	}

	my $facet;
	my $name = $self->param('name') || die "no name";

	my $all = $self->_param_scalar('all', 1);
	my $data = $self->_loaded('data');

	my $filters = $self->_current_filters;
	my $all_filters = join(' ',sort keys %$filters,'order:',$self->session('order'));
	my $filtered = $loaded->{$path}->{filtered}->{$all_filters}
		if defined $loaded->{$path}->{filtered}->{$all_filters};

	if ( ! $filtered || $all ) {
		$filtered = [ 0 .. $#{ $data->{items} } ];
		warn "filter all values\n";
	} else {
		warn "filter using $all_filters\n";
	}

	foreach my $i ( @$filtered ) {
		my $item = $data->{items}->[$i];
		if ( ! exists $item->{$name} ) {
			$facet->{ _missing }++;
		} elsif ( ref $item->{$name} eq 'ARRAY' ) {
			$facet->{$_}++ foreach @{ $item->{$name} };
		} else {
			$facet->{ $item->{$name} }++;
		}
	}

#	warn "# facet $name ",dump $facet;

	my $checked;
	my @facet_names =
		  $all                      ? keys %$facet
		: defined $filters->{$name} ? @{ $filters->{$name} }
		: keys %$facet;

	$checked = $self->_checked( @{ $filters->{$name} } ) if defined $filters->{$name};

	my $numeric = $self->_is_numeric($name);

	my $sort = $self->param('sort');
	# sort numeric facets with more than 5 values ascending
	$sort ||= $numeric && $#facet_names > 4 ? 'a' : 'c';

	@facet_names = sort {
		my $result;
		if ( $sort eq 'a' ) {
			$result = $numeric ? $a <=> $b : lc $a cmp lc $b;
		} elsif ( $sort eq 'd' ) {
			$result = $numeric ? $b <=> $a : lc $b cmp lc $a;
		} elsif ( $sort eq 'c' ) {
			$result = ( $facet->{$b} || -1 ) <=> ( $facet->{$a} || -1 )
		} else {
			warn "unknown sort: $sort";
			$result = $a cmp $b;
		}
		$result = $a cmp $b unless defined $result; # FIXME cludge for numeric facets with invalid data
		$result;
	} @facet_names;

	$self->render( name => $name, facet => $facet, checked => $checked,
		facet_names => \@facet_names, sort => $sort, numeric => $numeric,
	);
}


sub __invalidate_path_column {
	my ( $path, $name ) = @_;

	if ( defined $loaded->{$path}->{sorted}->{$name} ) {
		delete $loaded->{$path}->{sorted}->{$name};
		warn "# invalidate $path sorted $name\n";
	}

	foreach ( grep { m/$name/ } keys %{ $loaded->{$path}->{filtered} } ) {
		delete $loaded->{$path}->{filtered}->{$_};
		warn "# invalidate $path filtered $_\n";
	}
}

sub __path_modified {
	my ( $path, $value ) = @_;
	$value = 1 unless defined $value;
	
	$loaded->{$path}->{modified}  = $value;

	warn "# __path_modified $path $value\n";
}

sub edit {
	my $self = shift;
	my $new_content = $self->param('new_content');
	$new_content  ||= $self->param('content'); # backward compatibility with old actions

	my $i = $self->param('_row_id');
	die "invalid _row_id ",dump($i) unless $i =~ m/^\d+$/;
	my $path = $self->param('path') || die "no path";
	my $name = $self->param('name') || die "no name";
	my $status = 200; # 200 = OK, 201 = Created

	my $data = $self->_loaded('data');

	if ( defined $loaded->{$path}->{data}->{items}->[$i] ) {
		$new_content =~ s/^\s+//s;
		$new_content =~ s/\s+$//s;
		my $v;
		if ( $new_content =~ /\xB6/ ) {	# para
			$v = [ split(/\s*\xB6\s*/, $new_content) ];
		} else {
			$v = [ $new_content ];
		}

		my $old = dump $loaded->{$path}->{data}->{items}->[$i]->{$name};
		my $new = dump $v;
		if ( $old ne $new
			&& ! ( $old eq 'undef' && length($new_content) == 0 ) # new value empty, previous undef
		) {
			my $change = {
				path => $path,
				column => $name,
				pos => $i,
				old => $loaded->{$path}->{data}->{items}->[$i]->{$name},
				new => $v,
				time => $self->param('time') || time(),
				user => $self->param('user') || $ENV{'LOGNAME'},
				unique => {
					map { $_ => $loaded->{$path}->{data}->{items}->[$i]->{$_}->[0] }
					grep { defined $loaded->{$path}->{stats}->{$_}->{unique} }
					keys %{ $loaded->{$path}->{stats} }
				},
			};
			my $change_path = $self->_permanent_path( 'changes' );
			mkdir $change_path unless -d $change_path;
			$change_path .= '/' . $change->{time};
			store $change, $change_path;
			utime $change->{time}, $change->{time}, $change_path;
			warn "# $change_path ", dump($change);

			warn "# change $path $i $old -> $new\n";
			$loaded->{$path}->{data}->{items}->[$i]->{$name} = $v;

			__invalidate_path_column( $path, $name );

			$status = 201; # created
			# modified = 2 -- force rebuild of stats
			__path_modified( $path, 2 );
	
			$new_content = join("\xB6",@$v);

		} else {
			warn "# unchanged $path $i $old\n";
			$status = 304;
		}
	} else {
		$new_content = "$path $i $name doesn't exist\n";
		$status = 404;
	}

	warn "# edit $status ", dump $new_content;

	$self->render(
		status => $status,
		new_content => scalar $new_content,
	);
}


sub save {
	my $self = shift;
	my $path = $self->_param_or_session('path');
	my $dump_path = $self->_save( $path );
	__path_modified( $path, 0 );

	$self->redirect_to( '/data/items' );
}

sub export {
	my $self = shift;

	if ( my $import = $self->param('import') ) {

		if ( $import =~ m{/filter\.(.+?)\..+} ) {
			my $name = $1;
			my @vals = map { chomp; $_ }
				read_file $self->app->home->rel_dir('public') . "/export/$import";
			$self->_remove_filter( $name );
			$self->_filter_on_data( $name, @vals );
			$self->session( 'offset' => 0 );
			$self->redirect_to('/data/items');
		} else {
			warn "UNKNOWN IMPORT $import";
		}
	}

	$self->render( export => [
		glob( $self->_export_path . '*' )
	] );
}

sub __loaded_paths {
	return
		grep { defined $loaded->{$_}->{data} }
		keys %$loaded;
}

1;
