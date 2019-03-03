use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Iterator::Records::Files',
    AUTHOR           => q{Michael Roberts <michael@cpan.org>},
    VERSION_FROM     => 'lib/Iterator/Records/Files.pm',
    ABSTRACT_FROM    => 'lib/Iterator/Records/Files.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Iterator::Records' => 0,
        'Iterator::Simple' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Iterator-Records-Files-*' },
);
