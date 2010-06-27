foreach my $a ( @{ $row->{'Cited Author'} } ) {
	$a =~ s/^\.+//;
	push @{ $update->{'Cited Author'} }, uc $a;
}
