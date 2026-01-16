use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'MojoFacets',
  VERSION_FROM => 'lib/MojoFacets.pm',
  AUTHOR       => 'Dobrica Pavlinusic <dpavlin@rot13.org>',
  PREREQ_PM    => {
    'Mojolicious' => '9.00',
    'Data::Dump' => 0,
    'File::Slurp' => 0,
    'JSON' => 0,
    'HTML::TableExtract' => 0,
    'File::Path' => 0,
    'Text::Unaccent::PurePerl' => 0,
    'Statistics::Descriptive' => 0,
    'Text::CSV' => 0,
    'DBI' => 0,
    'DBD::SQLite' => 0,
  },
  test         => {TESTS => 't/*.t'},
);