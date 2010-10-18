foreach my $m ( @{ $row->{'MENTOR'} } ) {
 ( $update->{mentor_ime}, $update->{mentor_prezime} ) = split(/\s/,$m,2);
}
 
