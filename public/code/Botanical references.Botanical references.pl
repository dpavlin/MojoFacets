# modify column in-place
foreach my $v ( @{ $row->{'Botanical references'} } ) {
 $row->{'Botanical references'} = [ split(/\s*,\s*/,$v) ]
}
