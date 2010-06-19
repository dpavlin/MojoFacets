foreach my $by ( @{ $row->{'alpha'} } ) {
  $out->{ $by }->{ $_ }++ foreach @{ $row->{'repeatable'} };
}
