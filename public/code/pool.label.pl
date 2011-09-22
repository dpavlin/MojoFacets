foreach my $v ( @{ $row->{'pool'} } ) {
 my $drives = $v =~ s/sd/sd/g;
 my $vdevs  = $v =~ s/(raidz|mirror)/$1/g;
 my $c = $drives / $vdevs;
 $update->{label} = "$vdevs.$c";
}

