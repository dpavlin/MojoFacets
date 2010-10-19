map {
# warn dump $_;
 ( $update->{file_text}, $update->{file_nr} ) = ( $1, $2 ) if m/^(\d+)(\w+)$/;
} @{ $row->{'IME FILE-a'} };
 

