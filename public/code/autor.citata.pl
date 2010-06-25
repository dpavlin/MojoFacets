$key = 'autor'; $value = 'citata';

foreach my $a ( @{ $row->{autor_full} } ) {
 foreach my $c ( @{ $row->{broj_citata} } ) {
  $out->{$a} += $c;
 }
}
