foreach my $year ( @{ $row->{Year} } ) {
	push @{ $update->{century} }, int($year/100)+1;
}
