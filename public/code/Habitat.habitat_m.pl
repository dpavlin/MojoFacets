foreach my $v ( @{ $row->{Habitat} } ) {
 foreach my $m ( $v =~ m/\b(\d+,?\d*(?:\s*-\s*\d+,?\d*)?)\s*m(?:et)?/g ) {
  $m =~ s/,//g;
  push @{ $row->{habitat_m} }, $m;
 }
}
