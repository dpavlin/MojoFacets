foreach my $v ( @{ $row->{'pool'} } ) {
 my $drives = $v =~ s/sd/sd/g;
 my $vdevs  = $v =~ s/raidz/raidz/g || $v =~ s/mirror/mirror/g;
 my $c = $drives / $vdevs;
 $update->{label} = "$vdevs.$c";
}

