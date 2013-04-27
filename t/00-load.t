#!perl -T
use 5.010001;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Text::Amuse' ) || print "Bail out!\n";
}

diag( "Testing Text::Amuse $Text::AMuse::VERSION, Perl $], $^X" );
