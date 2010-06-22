foreach my $col ( grep { m/Datum/ } keys %$row ) {
 foreach my $v ( @{ $row->{$col} } ) {
  $v =~ s/(\d\d)\.(\d\d)\.(\d\d\d\d)/$3-$2-$1/;
  push @{ $update->{$col} }, $v;
 }
}
