map {
	s/^\.+//;
	$_ = uc $_;
} @{ $row->{'Cited Author'} };
