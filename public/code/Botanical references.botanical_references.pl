foreach my $v ( @{ $row->{'Botanical references'} } ) {
 $row->{botanical_references} = [ split(/\s*,\s*/,$v) ]
}