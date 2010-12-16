package MojoFacets::Import::CouchDB;

use warnings;
use strict;

use base 'Mojo::Base';

use File::Slurp;
use Data::Dump qw(dump);
use JSON;
use Mojo::Client;

__PACKAGE__->attr('path');
__PACKAGE__->attr('full_path');

sub flatten {
	my ($flat,$data,$prefix) = @_;
	if ( ref $data eq '' ) {
		push @{ $$flat->{$prefix} }, $data;
	} elsif ( ref $data eq 'HASH' ) {
		foreach my $key ( keys %$data ) {
			my $full_prefix = $prefix ? $prefix . '_' : '';
			$full_prefix .= $key;
			flatten( $flat, $data->{$key}, $full_prefix );
		}
	} elsif ( ref $data eq 'ARRAY' ) {
		foreach my $el ( @$data ) {
			flatten( $flat, $el, $prefix );
		}
	} elsif ( ref $data eq 'Mojo::JSON::_Bool' ) {
		push @{ $$flat->{$prefix} }, $data;
	} else {
		die "unsupported ",ref($data)," from ",dump($data);
	}
}

sub data {
	my $self = shift;

	my $path = $self->path;

	my $url = read_file $self->full_path;
	$url =~ s{/\s*$}{}s;

	warn "# CouchDB URL: $url";

	my $json = Mojo::Client->new->get( "$url/_all_docs?include_docs=true" )->res->json;

	my $data;

	if ( ref $json->{rows} eq 'ARRAY' ) {
		foreach my $doc ( @{$json->{rows}} ) {
			next if $doc->{id} =~ m{^_design/}; # $doc->{id} == $doc->{doc}->{_id}
			my $flat;
			flatten( \$flat, $doc->{doc}, '' );
			push @{ $data->{items} }, $flat;
		}
	}

	return $data;

}

1
