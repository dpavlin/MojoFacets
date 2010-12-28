package MojoFacets::Import::SQL;

use warnings;
use strict;

use base 'Mojo::Base';

use DBI;
use File::Slurp;
use Data::Dump qw(dump);
use Encode;

__PACKAGE__->attr('path');

sub data {
	my $self = shift;

	my $path = $self->path;

	my $sql = read_file $path, { binmode => ':raw' }; # FIXME configurable!

	my $dsn    = $1 if $sql =~ s/--\s*(dbi:\S+)//;
	my $user   = $1 if $sql =~ s/--\s*user:\s*(\S+)//;
	my $passwd = $1 if $sql =~ s/--\s*passwd:\s*(\S+)//;

	warn "# $dsn $user/", '*' x length($passwd);

	my $opts = { RaiseError => 1, AutoCommit => 0 };
	delete $opts->{AutoCommit} if $dsn =~ m/Gofer/; # not supported with Gofer

	if ( $dsn =~ m{Pg} ) {
		$opts->{pg_enable_utf8} = 1;
	} elsif ( $dsn =~ m{mysql} ) {
		$opts->{mysql_enable_utf8} = 1;
	} else {
		warn "utf-8 encoding can't be set for this dsn!";
	}

	my $dbh = DBI->connect($dsn, $user, $passwd, $opts) || die $DBI::errstr;

	warn "# SQL: $sql";
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	warn "# got ", $sth->rows, " rows\n";

	my $data = { items => [] };
	$data->{header} = [ $sth->{NAME} ];

	while( my $row = $sth->fetchrow_hashref ) {
		push @{ $data->{items} }, $row;
	}

	return $data;

}

1
