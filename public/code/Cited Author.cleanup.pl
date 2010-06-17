map {
	s/^\.+//;
	$_ = uc $_;
} @{ $rec->{'Cited Author'} };
