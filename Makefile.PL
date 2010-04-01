#!/usr/bin/env perl

use 5.008001;

use strict;
use warnings;

# Son, when you participate in sporting events,
# it's not whether you win or lose, it's how drunk you get.
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'MojoFacets',
    VERSION_FROM => 'lib/MojoFacets.pm',
    AUTHOR       => 'Dobrica Pavlinusic <dpavlin@rot13.org>',
    EXE_FILES => ['script/mojo_facets'],
    PREREQ_PM => { 'Mojo' => '0.9003' },
    test => {TESTS => 't/*.t t/*/*.t t/*/*/*.t'}
);