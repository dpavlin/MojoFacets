foreach my $v ( @{ $row->{Habitat} } ) {
 foreach my $ref ( $v =~ m/\[((?:\d+)(?:\s*,\s*\d+)?)\]/g ) {
  push @{ $row->{habitat_references} }, split(/\s*,\s*/,$ref);
 }
}