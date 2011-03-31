lookup($row->{issn}, 'nabava', => 'issn', sub {
 my $stat = shift;
 foreach my $rrp ( ref $on->{rrp} eq 'ARRAY' ? @{$on->{rrp}} : $on->{rrp} ) {
  push @{ $update->{rrp} }, $rrp;
  $stat->add_data( $rrp );
 }
},sub {
 my $stat = shift;
 $update->{prosjek} = $stat->mean;
});

