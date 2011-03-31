lookup($row->{alpha}, 'test2.js', => 'alpha2', sub {
 map {
  push @{$update->{on_id}} => $_;
 } @{$on->{id2}} 
});

