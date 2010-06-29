foreach my $v ( @{ $row->{'Botanical references'} } ) {
 $update->{botanical_references} = [ split(/\s*[,\.\s]\s*/,$v) ]
}

