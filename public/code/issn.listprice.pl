lookup($row->{issn}, 'nabava', => 'issn', sub {
  push @{ $update->{listprice} }, $on->{listprice};
});

