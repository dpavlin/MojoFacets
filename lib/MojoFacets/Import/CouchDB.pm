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

sub data {
	my $self = shift;

	my $path = $self->path;

	# we could use Mojo::JSON here, but it's too slow
#	$data = from_json read_file $path;
	my $url = read_file $self->full_path;
	$url =~ s{/\s*$}{}s;

	warn "# CouchDB URL: $url";

	my $json = Mojo::Client->new->get( "$url/_all_docs?include_docs=true" )->res->json;

	my $data;

	if ( ref $json->{rows} eq 'ARRAY' ) {
		foreach my $doc ( @{$json->{rows}} ) {
			push @{ $data->{items} }, $doc->{doc};
		}
	}

	return $data;

}

1
