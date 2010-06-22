foreach my $col ( grep { m/(Duguje|Potra.uje|Saldo)/ } keys %$row ) {
 foreach my $v ( @{ $row->{$col} } ) {
  push @{ $update->{ $col . '_old' } }, $v;
  $v =~ s/(\d+)?\.?(\d{0,3})\,(\d{2})/$1$2.$3/;
  $v *= 1;
  push @{ $update->{$col} }, $v;
 }
}
