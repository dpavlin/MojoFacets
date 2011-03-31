lookup($row->{issn}, 'nabava', => 'issn', sub {
  push @{ $update->{listprice} }, $on->{listprice};
  shift->add_data( $on->{listprice} );
},sub {
 my $stat = shift;
 $update->{price_min} = $stat->min;
# $update->{price_max} = $stat->max;
 $update->{price_check} = $stat->min * 5 - $row->{cijena}->[0];
});

