requires 'Mojolicious', '>= 9.0';
requires 'Data::Dump';
requires 'File::Slurp';
requires 'JSON';
requires 'HTML::TableExtract';
requires 'File::Path';
requires 'Text::Unaccent::PurePerl';
requires 'Statistics::Descriptive';
requires 'Text::CSV';
requires 'DBI';
requires 'DBD::SQLite';
requires 'Storable';
requires 'Time::HiRes';
requires 'Digest::MD5';

on 'test' => sub {
  requires 'Test::More';
};
