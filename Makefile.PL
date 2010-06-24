use inc::Module::Install;

name 'MojoFacets';
version_from 'lib/MojoFacets.pm';
author 'Dobrica Pavlinusic <dpavlin@rot13.org>';
license 'dual';

requires 'Mojo' => '0.9003';
requires 'Data::Dump';
requires 'File::Slurp';
requires 'JSON';
requires 'HTML::TableExtract';
requires 'File::Path';
requires 'Text::Unaccent::PurePerl';

build_requires 'Test::More';

auto_install;

WriteAll;
