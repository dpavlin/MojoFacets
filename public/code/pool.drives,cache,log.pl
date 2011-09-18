foreach my $v ( @{ $row->{'pool'} } ) {
 $update->{$_} = $v =~ s/(\+$_)/$1/ foreach ( 'cache', 'log' );
 $update->{drives} = $v =~ s/sd/sd/g;
}

