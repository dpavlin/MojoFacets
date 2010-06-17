foreach my $year ( @{ $row->{Year} } ) {
	push @{ $row->{century} }, int($year/100)+1;
}
