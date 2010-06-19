foreach my $author ( @{ $row->{'Cited Author'} } ) {
  $out->{ $author }->{ $_ }++ foreach @{ $row->{'Year'} };
}