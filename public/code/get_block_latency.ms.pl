foreach my $col ( grep { m/latency/ } keys %$row ) {
 foreach my $v ( @{ $row->{$col} } ) {
  $v =~ s{(\d+)us}{$1 / 1000}e;
  $v =~ s{(\d+)ms}{$1};
  push @{ $update->{$col . '_ms' } }, $v;
 }
}

