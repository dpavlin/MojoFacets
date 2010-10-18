foreach my $v ( @{ $row->{'PREZIME'} } ) {
 $update->{prezime_ucfirst} = ucfirst lc $v;
}
 
