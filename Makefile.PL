#!/usr/bin/env perl

use 5.008001;

use strict;
use warnings;

# Son, when you participate in sporting events,
# it's not whether you win or lose, it's how drunk you get.
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'MyApp',
    VERSION_FROM => 'lib/MyApp.pm',
    AUTHOR       => 'A Good Programmer <nospam@cpan.org>',
    EXE_FILES => ['script/my_app'],
    PREREQ_PM => { 'Mojo' => '0.9003' },
    test => {TESTS => 't/*.t t/*/*.t t/*/*/*.t'}
);
