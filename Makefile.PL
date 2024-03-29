use inc::Module::Install;

name 'MojoFacets';
version_from 'lib/MojoFacets.pm';
author 'Dobrica Pavlinusic <dpavlin@rot13.org>';
license 'dual';

requires 'Mojolicious' => '6.66';
requires 'Data::Dump';
requires 'File::Slurp';
requires 'JSON';
requires 'HTML::TableExtract';
requires 'File::Path';
requires 'Text::Unaccent::PurePerl';
requires 'Statistics::Descriptive';
requires 'Text::CSV';

features(
	'profile' => [
		-default => 0,
		'Time::HiRes',
		'Devel::NYTProf',
	],
);

build_requires 'Test::More';

auto_install;

WriteAll;
