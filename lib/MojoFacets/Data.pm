package MojoFacets::Data;

use strict;
use warnings;

use base 'Mojolicious::Controller';

#use Data::Dump qw(dump); # broken with Mojo::JSON, see https://rt.cpan.org/Public/Bug/Display.html?id=86592
use Data::Dumper;
use subs 'dump';
sub dump { Dumper(@_) };

use File::Slurp;
use Encode;
use locale;
use File::Find;
use Storable;
use Time::HiRes qw(time);
use File::Path qw(mkpath);
use Text::Unaccent::PurePerl;
use Digest::MD5;
use Statistics::Descriptive;

our $imports;
foreach my $module ( glob('lib/MojoFacets/Import/*.pm') ) {
	$module =~ s{lib/(\w+)/(\w+)/(.*)\.pm}{$1::$2::$3};
	eval "use $module";
	die "$module: $!" if $!;
	my ( $ext, $priority ) = $module->ext;
	$imports->{$priority || 'file'}->{$ext} = $module;
	warn "# import $ext $module\n";
}

warn "# import loaded ",dump( $imports );

sub import_module {
	my $full_path = shift;

#	warn "# import_module $full_path\n";

	return if $full_path =~ m/\.columns$/;

	foreach my $ext ( keys %{ $imports->{file} } ) {
		if ( -f $full_path && $full_path =~ m/$ext/i ) {
			return $imports->{file}->{$ext};
			last;
		}
	}

	foreach my $ext ( keys %{ $imports->{directory} } ) {
		if ( -f $full_path && $full_path =~ m/$ext/i ) {
			return $imports->{directory}->{$ext};
			last;
		}
	}
}

our $loaded;
our $filters;

sub index {
	my $self = shift;

	my $data_dir = $self->app->home->rel_file('data');
	die "no data dir $data_dir" unless -d $data_dir;

	my @files;
	my $changes;

	find( sub {
		my $file = $File::Find::name;

		next if $file =~ m/.timefmt$/;

		if ( -f $file && $file =~ m/([^\/]+)\.changes\/(\d+[\.,]\d+.+)/ ) {
			push @{ $changes->{$1} }, $2
		} elsif ( import_module( $file ) ) {
			my $mtime = (stat($file))[9]; # mtime
			$file =~ s/$data_dir\/*//;
			push @files, $file;
			$loaded->{$file}->{mtime} ||= $mtime;
		} else {
			#warn "IGNORE: $file\n";
		}
	}, $data_dir);

	no warnings qw(uninitialized); # mtime
	@files = sort { $loaded->{$b}->{mtime} <=> $loaded->{$a}->{mtime} || lc $a cmp lc $b } @files,
			grep { defined $loaded->{$_}->{generated} } keys %$loaded;

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
	my $dir = $self->app->home->rel_file('data');
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

#	foreach my $e ( @{ $_[0] } ) {
	foreach my $i ( 0 .. $#{$_[0]} ) {
		print STDERR " $i" if $i % 5000;
		my $e = $_[0]->[$i];
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
				if ( ! defined $x ) { # FIXME really null
					$stats->{$n}->{empty}++;
					next;
				}

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
	return $self->redirect_to( '/data/columns' );
}


sub _load_path {
	my ( $self, $path ) = @_;

	return if defined $loaded->{$path}->{generated};

	my $full_path = $self->app->home->rel_file( 'data/' . $path );
	return $self->redirect_to('/data/index') unless -r $full_path;

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
	if ( my $module = import_module( $full_path ) ) {
		$data = $module->new( full_path => $full_path )->data;
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
		defined $data->{generated} ? ( generated => 1 ) : (),
	};

	$loaded->{ $path } = $info;
	$self->_save( $path ) unless $info->{generated};


}


sub load {
	my $self = shift;

	my @paths = @{ $self->every_param('paths') };
	warn "# paths ", dump @paths;

	foreach my $p ( keys %$loaded ) {
		next if grep { /^\Q$p\E$/ } @paths;
		warn "remove $p from memory\n";
		delete $loaded->{$p};
	}

	$self->_load_path( $_ ) foreach @paths;

 	my $path = $self->param('path') || $self->session('path') || $paths[0] || $self->redirect_to('/data/index');

	warn "# path $path\n";
	$self->_load_path( $path );

	$self->session( 'path' => $path );

	my $timefmt_path = $self->_permanent_path( 'timefmt' );
	if ( -e $timefmt_path ) {
		my $timefmt = read_file $timefmt_path;
		$self->session( 'timefmt', $timefmt );
		warn "timefmt = ", $timefmt;
	}

	my $redirect_to = '/data/items';

	$self->session( 'header' => $loaded->{$path}->{header} );
	if ( ! defined $loaded->{$path}->{columns} ) {
		my $columns_path = $self->_permanent_path( 'columns' );
		if ( -e $columns_path ) {
			my @columns = map { s/[\r\n]+$//; $_ } read_file $columns_path, binmode => ':utf8';
			$loaded->{$path}->{columns} = [ @columns ];
			warn "# columns_path $columns_path ",dump(@columns);
		} else {
			$loaded->{$path}->{columns} = $loaded->{$path}->{header}
		}

		$redirect_to = '/data/columns';
	}
	$self->session( 'columns' => $loaded->{$path}->{columns} );
	$self->session( 'order'   => $loaded->{$path}->{columns}->[0] );
	return $self->redirect_to( $redirect_to );
}


sub _loaded {
	my ( $self, $name ) = @_;
	my $path = $self->session('path') || $self->param('path');
	return $self->redirect_to('/data/index') unless $path;

	if ( defined $loaded->{$path}->{modified} && $loaded->{$path}->{modified} > 1 ) {
		my $caller = (caller(1))[3];
		if ( $caller =~ m/::edit/ ) {
			warn "rebuild stats for $path ignored caller $caller\n";
		} else {
			warn "rebuild stats for $path FORCED by modified caller $caller\n";
#			$loaded->{$path}->{stats} = __stats( $loaded->{$path}->{data}->{items} );
			$loaded->{$path}->{rebuild_stats} = 1;
			$loaded->{$path}->{modified} = 1;
		}
	}

	if ( defined $loaded->{$path}->{rebuild_stats} ) {
		warn "rebuild_stats $path";
		$loaded->{$path}->{stats} = __stats( $loaded->{$path}->{data}->{items} );
		delete $loaded->{$path}->{rebuild_stats};
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
			return $self->redirect_to('/data/index')
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
	$self->app->home->rel_file('data') . '/' . join('.', $path, @_);
}

sub __unac {
	my $n = shift;
	$n = unac_string('utf-8',$n);
	$n =~ s/\W+/_/g;
	return $n;
}

sub _column_from_unac {
	my ($self,$name) = @_;

	my $stats = $self->_loaded('stats');
	my $cols_norm = { map { __unac( $_ ) => $_ } keys %$stats };

	$cols_norm->{$name} || die "can't find column $name in ", dump($cols_norm);
}

sub _export_path {
	my $self = shift;
	my $path = $self->_param_or_session('path');
	if ( ! $path ) {
		warn "no path in param or session";
		return;
	}
	my $dir = $self->app->home->rel_file('public') . "/export/$path";
	mkpath $dir unless -e $dir;
	my $name = __export_path_name( $path, @_ );
	my $full = $dir . '/' . $name;
	$full =~ s/\/+$// if -d $full; # strip trailing slash for dirs
	return $full;
}

sub __export_path_name {
	my $max_length = 80;

	my $path = shift;
	my $name = join('.', map { __unac($_) } @_ );
	if ( length($name) > $max_length ) {
		$name = substr($name,0,$max_length) . Digest::MD5::md5_hex substr($name,$max_length);
	}
	return $name;
}

sub columns {
    my $self = shift;

	my $view_path = $self->_permanent_path( 'views' );

	if ( $self->param('columns') ) {
		my @columns = $self->_param_array('columns');
		write_file( $self->_permanent_path( 'columns' ), { binmode => ':utf8' }, map { "$_\n" } @columns );
		if ( my $view = $self->param('view') ) {
			mkdir $view_path unless -e $view_path;
			write_file( "$view_path/$view", { binmode => ':utf8' }, map { "$_\n" } @columns );
			warn "view $view_path/$view ", -s "$view_path/$view", " bytes\n";
		}

		return $self->redirect_to('/data/items');

	} elsif ( ! $self->session('header') ) {
		return $self->redirect_to('/');
		return $self->redirect_to('/data/load');
	}

	if ( my $id = $self->param('id') ) {
		my $view_full = "$view_path/$id";
		if ( -f $view_full ) {
			my @columns = map { chomp; $_ } read_file $view_full, binmode => ':utf8';
			warn "view $view_full loaded ", dump @columns;
			$self->session( 'columns' => [ @columns ] );
			return $self->redirect_to('/data/items');
		}
	}

	my $stats = $self->_loaded( 'stats' );

	my @columns;
	@columns = grep { defined $stats->{$_}->{count} } @{ $self->session('columns') } if $self->session('columns');

	foreach my $c ( @{ $self->session( 'header' ) } ) {
		push @columns, $c unless grep { /^\Q$c\E$/ } @columns;
	}

	my @views;
	if ( -d $view_path ) {
		@views = map { s{^\Q$view_path\E/*}{}; $_ } glob "$view_path/*";
		warn "# views ",dump @views;
	}

    $self->render(
		message => 'Select columns to display',
		stats => $stats,
		columns => \@columns,
		checked => $self->_checked( $self->_param_array('columns') ),
		views => \@views,
	);
}

sub _param_array {
    my ($self,$name) = @_;

	my @array = @{ $self->every_param($name) };
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
		if ( defined $scalar ) {
			$self->session($name => $scalar);
		} else {
			warn "no default for $name";
		}
	}

	warn "# _param_scalar $name ",dump $scalar;
	return $scalar;
}

sub filter {
	my $self = shift;

	my $name = $self->param('filter_name') || die "name?";
	my @vals = @{ $self->every_param('filter_vals') };

	$self->_remove_filter( $name );
	if ( @vals ) {
		$self->_filter_on_data( $name, @vals );
		if ( my $permanent = $self->param('_permanent') ) {
			my $permanent_path = $self->_export_path( 'filter', $name, $permanent );
			write_file $permanent_path, { binmode => ':utf8' }, map { "$_\n" } @vals;
			warn "permanent filter $permanent_path ", -s $permanent_path;
		}
	}

	$self->session( 'offset' => 0 );

	return $self->redirect_to('/data/items');
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
			my $row = $items->[$i]->{$name};
			$row = [ $row ] unless ref $row eq 'ARRAY'; # FIXME probably wrong place
			foreach my $v ( @$row ) {
				if ( defined $filter_hash->{ $v } ) {
					$filtered_items->{$i}++;
				}
			}
		} elsif ( $include_missing ) {
			$filtered_items->{$i}++;
		}
	}

	#warn "# filter $name ",dump($filtered_items);

	# invalidate filters on other datasets
	foreach my $dataset ( grep { exists $loaded->{$_}->{filters}->{$name} } keys %$loaded ) {
		delete $loaded->{$dataset}->{filters}->{$name};
		delete $loaded->{$dataset}->{filtered};
	}

	$loaded->{$path}->{filters}->{$name} = $filtered_items;
	warn "filter $name with ", scalar keys %$filtered_items, " items created\n";
}


sub _current_filters {
	my $self = shift;
	my $current_filters;
	my $stats = $self->_loaded('stats');

	$current_filters->{ $_ } = $filters->{ $_ }
		foreach ( grep { defined $filters->{ $_ } } keys %$stats )
	;
	warn "# _current_filters ",dump( keys %$current_filters );
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
		my $v;
		if ( ! exists $_->{$order} ) {
			$v = $missing;
		} elsif ( ref $_->{$order} eq 'ARRAY' ) {
			$v = join('', @{$_->{$order}});
		} else {
			$v = $_->{$order};
		}
		[ $nr++, $v ]
	} @{ $data->{items} }
	;

	warn "sorted: $order numeric: $numeric items: ", $#sorted + 1, "\n";
	#warn "# sorted ",dump( @sorted );

	$loaded->{$path}->{sorted}->{$order} = [ @sorted ];
}


sub __all_filters {
	my $order = pop @_;
	join(',', sort(@_), 'order', $order);
}

our ($out, $key,$value);

our $lookup_path_col;
our $on;

sub __commit_begin {
	warn "__commit_begin";
	$lookup_path_col = undef;
	$on = undef;
}

sub __commit_end {
	warn "__commit_end";
	$lookup_path_col = undef; # cleanup memory
	$on = undef;
}

sub lookup {
	warn "# lookup ",dump @_;
	my ( $vals, $on_path, $on_col, $code, $stat_code ) = @_;
	die "code is not sub{ ... } but ", dump $code unless ref $code eq 'CODE';

	if ( ! exists $loaded->{$on_path} ) {
		my @possible_paths = grep { /\Q$on_path\E/ } keys %$loaded;
		die "more than one dataset available for '$on_path' ",dump @possible_paths if $#possible_paths > 0;
		$on_path = shift @possible_paths;
		warn "## fuzzy selected path $on_path";
	}

	my $items = $loaded->{$on_path}->{data}->{items} || die "no items for $on_path";

	if ( ! exists $lookup_path_col->{$on_path}->{$on_col} ) {
		warn "create lookup_path_col $on_path $on_col";
		foreach my $i ( 0 .. $#$items ) {
			my $item = $items->[$i];
			if ( exists $item->{$on_col} ) {
				if ( ref $item->{$on_col} eq 'ARRAY' ) {
					foreach my $v ( @{ $item->{$on_col} } ) {
						push @{ $lookup_path_col->{$on_path}->{$on_col}->{$v} }, $i;
					}
				} elsif ( ! ref $item->{$on_col} ) { # scalar
					my $v = $item->{$on_col};
					push @{ $lookup_path_col->{$on_path}->{$on_col}->{$v} }, $i;
				} else {
					die "unknown type of ",dump $item->{$on_col};
				}
			}
		}
		warn "XXX ",dump $lookup_path_col->{$on_path}->{$on_col} if $ENV{DEBUG};
	}

	my $stat;
	$stat = Statistics::Descriptive::Full->new() if $stat_code;

	foreach my $v ( ref $vals eq 'ARRAY' ? @$vals : ( $vals ) ) {
		foreach my $i ( @{ $lookup_path_col->{$on_path}->{$on_col}->{$v} } ) {
			$on = $items->[$i];
			warn "XXX lookup code $v $i ",dump $on if $ENV{DEBUG};
			$code->($stat);
		}
		$stat_code->( $stat ) if $stat_code;
	}
}

sub __commit_path_code {
	my ( $path, $i, $code, $commit_changed ) = @_;

	my $items = $loaded->{$path}->{data}->{items} || die "no items for $path";
	my $row = $items->[$i];
	my $update;
	eval $code;
	foreach ( keys %$update ) {
		$$commit_changed->{$_}++;
		$loaded->{$path}->{data}->{items}->[$i]->{$_} = $update->{$_};
	}
	#warn "__commit_path_code $path $i ",dump( $update );
}

# uses templates/admin.html.ep
sub _switch_dataset {
	my $self = shift;

	my $datasets;

	foreach my $path ( keys %$loaded ) {
		next unless exists $loaded->{$path}->{data};
		push @$datasets, $path;
	}

	warn "# datasets ",dump($datasets);

	$self->stash( 'datasets' => $datasets );
}

sub items {
	my $self = shift;

	$self->_switch_dataset;

	if ( my $timefmt = $self->param('timefmt') ) {
		$self->session('timefmt', $timefmt);
		warn "session store timefmt $timefmt\n";
		my $timefmt_path = $self->_permanent_path( 'timefmt' );
		write_file $timefmt_path, $timefmt;
		warn "## $timefmt_path $timefmt"
	}

	if ( my $show = $self->param('id') ) {
		$self->param('show', $show);
		warn "show $show\n";
	}

	my $path = $self->_param_scalar('path');

	my @columns = $self->_param_array('columns');
	return $self->redirect_to('/data/columns') unless @columns;
	my $order   = $self->_param_scalar('order', $columns[0]);
	my $sort    = $self->_param_scalar('sort', 'a');
	my $offset  = $self->_param_scalar('offset', 0);
	my $limit   = $self->_param_scalar('limit', 20);
	$self->_param_scalar('show', 'table');

	# fix offset when changing limit
	$offset = int( $offset / $limit ) * $limit;

	if ( ! grep { /^\Q$order\E$/ } @columns ) {
		$order = $columns[0];
		$self->session( order => $order );
	}
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

	my $all_filters = __all_filters( @filter_names,$order );

#	warn "# all_filters $all_filters ", dump( $loaded->{$path}->{filtered}->{$all_filters} );

	if ( ! defined $loaded->{$path}->{filtered}->{$all_filters} ) {

		my $path_filters = $loaded->{$path}->{filters};

		warn "create combined filter for $all_filters from ", $#$sorted + 1, " items\n";

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

	my $data = $self->_loaded('data');

	my $code = $self->_param_scalar('code','');
	$code =~ s{\r}{}gs;
	$code =~ s{\n+$}{\n}s;

	# XXX convert @row->{foo} into @{$row->{foo}}
	$code =~ s|\@(row->\{[^}]+\})|\@{\$$1}|gs;

	my $commit = $self->param('commit');
	my $test = $self->param('test');

	my $commit_changed;
	__commit_begin;

	if ( $code && ( $test || $commit ) ) {
		# XXX find columns used in code snippet and show them to user
		my $order = 0;
		foreach my $column ( $code =~ m/\$row->\{([^}]+)\}/g ) {
			if ( $column =~ s/^(['"])// ) {
				$column =~ s/$1$//;
			}
			next if $column =~ m/\$/; # hide columns with vars in them
			$commit_changed->{$column} = 0;
		}
	}

	my $code_path = $self->app->home->rel_file('public') . "/code";
	if ( $commit ) {

		__path_modified( $path, 'commit' );

		warn "# commit on ", $#$filtered + 1, " items:\n$code\n";
		( $key, $value, $out ) = ( 'key', 'value' );
		foreach ( 0 .. $#$filtered ) {
			my $i = $filtered->[$_];
			__commit_path_code( $path, $i, $code, \$commit_changed );
		}

		# this might move before $out to recalculate stats on source dataset?
		__path_rebuild_stats( $path );
		my $c = { map { $_ => 1 } @columns };
		my @added_columns = sort grep { ! $c->{$_} } keys %$commit_changed;
		warn "# added_columns ",dump( @added_columns );
		unshift @columns, @added_columns;

		$loaded->{$path}->{columns} = [ @columns ];
		warn "# new columns ",dump( @columns );

		__invalidate_path_column( $path, $_ ) foreach keys %$commit_changed;

		$self->_save_change({
			path => $path,
			time => $self->param('time') || time(),
			user => $self->param('user') || $ENV{'LOGNAME'},
			code => $code,
			commit_changed => $commit_changed,
		});

		if ( my $description = $self->param('code_description') ) {
			my $depends = $self->param('code_depends') || die "no code_depends?";
			my $path = "$code_path/$depends.$description.pl";
			if ( -e $path && ! $self->param('overwrite') ) {
				warn "# code $path not saved\n";
			} else {
				write_file(  $path, { binmode => ':utf8' }, "$code\n" );
				warn "code $path ", -s $path, " bytes saved\n";
			}
		}

		# remove console
		$code = '';
		if ( $out ) {
			my $commit_dataset = join('.'
				, $self->param('code_depends')
				, $self->param('code_description')
				, time()
			);
			$key ||= 'key';
			$value ||= 'value';
			warn "key $key value $value";
			my $items;
			foreach my $n ( keys %$out ) {
				my $i = { $key => [ $n ] };
				my $ref = ref $out->{$n};
				if ( $ref eq 'HASH' ) {
					$i->{$_} = [ $out->{$n}->{$_} ] foreach keys %{ $out->{$n} };
				} elsif ( $ref eq 'ARRAY' ) {
					$i->{$_} = $out->{$n};
				} elsif ( ! $ref ) {
					$i->{$value} = [ $out->{$n} ];
				} else {
					$i->{_error} = [ dump($out->{$n}) ];
				}
				push @$items, $i;
			};
			undef $out;
			my $stats = __stats( $items );
			my @columns = grep { ! m/^\Q$key\E$/ } sort keys %$stats;
			unshift @columns, $key;

			$loaded->{$commit_dataset} = {
				header => [ @columns ],
				columns => [ @columns ],
				mtime => time(),
				data => { items => $items },
				stats => $stats,
				generated => 1,
			};
			warn "# loaded out ", dump( $loaded->{$commit_dataset} );
			$self->session('path', $commit_dataset);
			$self->session('columns', [ @columns ]);
			$self->session('order', $key);
			return $self->redirect_to('/data/items');
		}

		$self->session('columns', [ @columns ]);
	}

	my $sorted_items;
	my $from_end = $sort eq 'd' ? $#$filtered : 0;
	my $test_changed;
	my ( $key, $value, $out ) = ( 'key', 'value' ); # XXX make local
	foreach ( 0 .. $limit ) {
		my $i = $_ + $offset;
		last unless defined $filtered->[$i];
		$i = $from_end - $i if $from_end;
		my $id = $filtered->[$i];
		my $row = Storable::dclone $data->{items}->[ $id ];
		if ( $code && $test ) {
			my $update;
			eval $code;
			if ( $@ ) {
				warn "ERROR evaling $@", dump($code);
				$self->stash('eval_error', $@) if $@;
			} else {
				warn "EVAL ",dump($update);
				foreach ( keys %$update ) {
					$test_changed->{$_}++;
					$row->{$_} = $update->{$_};
				}
			}
		}
		$row->{_row_id} ||= $id;
		push @$sorted_items, $row;
	}

	if ( $self->param('export') ) {
		my $export_path = $self->_export_path( 'items', @columns);
		open(my $fh, '>', $export_path) || die "ERROR: can't open $export_path: $!";
		print $fh "#",join("\t",@columns),"\n";
		foreach my $f ( 0 .. $#$filtered ) {
			print $fh join("\t", map {
				my $i = $data->{items}->[ $filtered->[$f] ];
				my $v = '\N';
				if ( ! defined $i->{$_} ) {
					# nop
				} elsif ( ref $i->{$_} eq 'ARRAY' ) {
					$v =join(',', @{ $i->{$_} });
					$v = '\N' if length($v) == 0;
				} elsif ( ! ref $i->{$_} ) {
					$v = $i->{$_};
				} else {
					$v = dump $i->{$_};
				}
				$v;
			} @columns),"\n";
		}
		close($fh);
		warn "export $export_path ", -s $export_path, " bytes\n";
	}

	my ( $code_depends, $code_description );

	if ( $test ) {

		warn "# test_changed ",dump( $test_changed );
		my $c = { map { $_ => 1 } @columns };
		my @added_columns = sort grep { ! $c->{$_} } keys %$test_changed;
		unshift @columns, @added_columns;

		warn "# sorted_items ", $#$sorted_items + 1, " offset $offset limit $limit order $sort";

		my $depends_on;
		my $tmp = $code; $tmp =~ s/\$row->\{(['"]?)([\w\s]+)\1/$depends_on->{$2}++/gse;
		warn "# depends_on ",dump $depends_on;

		my $test_added = Storable::dclone $test_changed;
		delete $test_added->{$_} foreach keys %$depends_on;

		$code_depends = $self->param('code_depends')
		|| join(',', keys %$depends_on);

		$code_description = $self->param('code_description') ||
		join(',', keys %$test_added);

		$code_depends ||= $code_description; # self-modifing
		if ( ! $code_depends && $out ) {
			$code_depends = $key;
			$code_description = $value;
		}

		warn "# test_changed ",dump( $test_changed, $code_depends, $code_description );

	} # test?

	__commit_end;

	$self->render(
		order => $order,
		offset => $offset,
		limit => $limit,
		sorted => $sorted_items,
		columns => [ @columns ],
		rows => $#$filtered + 1,
		numeric => { map { $_, $self->_is_numeric($_) } @columns },
		unique  => { map { $_, $self->_is_unique( $_) } @columns },
		filters => $self->_current_filters,
		code => $code,
		cols_changed => $commit ? $commit_changed : $test_changed,
		code_depends => $code_depends,
		code_description => $code_description,
		code_path => $code_path,
		out => $out,
	);

}


sub order {
	my $self = shift;
	$self->session('order', $self->param('order'));
	$self->session('sort', $self->param('sort'));
	return $self->redirect_to('/data/items');
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

sub _is_unique {
	my ( $self, $name ) = @_;
	my $stats = $self->_loaded( 'stats' );
	defined $stats->{$name}->{unique};
}

sub _remove_filter {
	my ($self,$name) = @_;
	warn "_remove_filter $name\n";

	my $path = $self->session('path');

	delete $filters->{$name};
	delete $loaded->{$path}->{filters}->{$name};
	warn "filters left: ", keys %{ $loaded->{$path}->{filters} };

	foreach (
			grep { /\Q$name\E/ }
			keys %{ $loaded->{$path}->{filtered} }
	) {
		delete $loaded->{$path}->{filtered}->{$_};
		warn "remove filtered cache $_";
	}
}

sub facet {
	my $self = shift;

	my $path = $self->session('path') || return $self->redirect_to( '/data/index' );

	if ( my $name = $self->param('remove') ) {
		$self->_remove_filter( $name );
		return $self->redirect_to( '/data/items' );
	}

	my $facet;
	my $name = $self->param('name') || die "no name";

	my $all = $self->_param_scalar('all', 1);
	my $data = $self->_loaded('data');

	my $filters = $self->_current_filters;
	my $all_filters = __all_filters( keys %$filters,$self->session('order') );
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
		if ( ! exists $item->{$name} || ! defined $item->{$name} ) {
			$facet->{ _missing }++;
		} elsif ( ref $item->{$name} eq 'ARRAY' ) {
			$facet->{$_}++ foreach @{ $item->{$name} };
		} else {
			$facet->{ $item->{$name} }++;
		}
	}

	my $checked_values = $self->_checked( @{ $filters->{$name} } ) if defined $filters->{$name};

	if ( my $code = $self->param('code') ) {
		my $out;
		foreach my $value ( keys %$facet ) {
			my $count = $facet->{$value};
			my $checked = $checked_values->{$value};
			eval $code;
			if ( $@ ) {
				$out = $@;
				warn "ERROR: $@\n$code\n";
				last;
			} elsif ( $checked != $checked_values->{$value} ) {
				warn "checked $value $count -> $checked\n";
				$checked_values->{$value} = $checked;
			}
		}
		warn "out ",dump( $out );
		$self->stash( out => $out );
	}

#	warn "# facet $name ",dump $facet;

	my @facet_names =
		  $all                      ? keys %$facet
		: defined $filters->{$name} ? @{ $filters->{$name} }
		: keys %$facet;

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

	$self->render( name => $name, facet => $facet, checked => $checked_values,
		facet_names => \@facet_names, sort => $sort, numeric => $numeric,
	);
}


sub __invalidate_path_column {
	my ( $path, $name ) = @_;

	if ( defined $loaded->{$path}->{sorted}->{$name} ) {
		delete $loaded->{$path}->{sorted}->{$name};
		warn "# invalidate $path sorted $name\n";
	}

	foreach ( grep { m/\Q$name\E/ } keys %{ $loaded->{$path}->{filtered} } ) {
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

sub __path_rebuild_stats { $loaded->{ $_[0] }->{rebuild_stats} = 1 };

sub _save_change {
	my ($self,$change) = @_;

	my $change_path = $self->_permanent_path( 'changes' );
	mkdir $change_path unless -d $change_path;
	$change_path .= '/' . $change->{time};
	store $change, $change_path;
	utime $change->{time}, $change->{time}, $change_path;
	warn "_save_change $change_path ", dump($change);
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
			$self->_save_change({
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
			});

			warn "# change $path $i $old -> $new\n";
			$loaded->{$path}->{data}->{items}->[$i]->{$name} = $v;

			__invalidate_path_column( $path, $name );

			$status = 201; # created
			__path_rebuild_stats( $path );
	
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

	return $self->redirect_to( '/data/items' );
}

sub export {
	my $self = shift;

	my $dir = $self->app->home->rel_file('public');

	if ( my $import = $self->param('import') ) {

		if ( $import =~ m{/filter\.(.+?)\..+} ) {
			my $name = $self->_column_from_unac( $1 );

			my @vals = map { chomp; $_ }
				read_file "$dir/export/$import", binmode => ':utf8';

			$self->_remove_filter( $name );
			$self->_filter_on_data( $name, @vals );
			$self->session( 'offset' => 0 );
			return $self->redirect_to('/data/items');
		} else {
			warn "UNKNOWN IMPORT $import";
		}
	}

	if ( my $remove = $self->param('remove') ) {
		my $path = "$dir/export/$remove";
		unlink $path if -e $path;
		$path .= '.png';
		unlink $path if -e $path;
	}

	my $path = $self->_export_path || return $self->redirect_to('/data/index');

	my @files = grep { ! /\.png$/ } glob "$path/*";
	my $mtime = { map { $_ => (stat($_))[9] } @files };
	@files = sort { $mtime->{$b} <=> $mtime->{$a} } @files;
	$self->render( export => [ @files ] );
}

sub __loaded_paths {
	return
		grep { defined $loaded->{$_}->{data} }
		keys %$loaded;
}

sub reload {
	my $self = shift;
	$self->stash( reload => 1 );
	$self->remove;
#	$self->_load_path( $self->param('path') );
	$self->redirect_to('/data/load?path=' . $self->param('path') );
}

sub remove {
	my $self = shift;
	my $path = $self->param('path');
	if ( $path =~ m{^/tmp/mojo_facets\.} ) {
		unlink $path;
		warn "# unlink $path";
		if ( my $name = $self->param('name') ) {
			delete $loaded->{$name};
			warn "# remove $name from memory";
		}
	} else {
		warn "WARNING: $path unlink ignored";
	}
	return if $self->stash('reload');
	return $self->redirect_to( '/data/load' );
}

1;
