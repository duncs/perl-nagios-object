#!/usr/bin/perl -w

use lib qw( ../lib ./lib );
use Test::More qw(no_plan);
use Test::NoWarnings;

use_ok('Nagios::Object');

diag("creating an object ...") if ( $ENV{TEST_VERBOSE} );
my $tp = Nagios::TimePeriod->new(
    timeperiod_name => '24x7',
    alias           => '24x7',
    sunday          => '00:00-24:00',
    monday          => '00:00-12:00,12:00-24:00',
    tuesday         => '00:00-24:00',
    wednesday       => '00:00-24:00',
    thursday        => '00:00-24:00',
    friday          => '00:00-24:00',
    saturday        => '00:00-24:00'
);
isa_ok( $tp, 'Nagios::Object' );
is( $tp->use, undef, "use() should return undef for top-level objects" );

my $next = $tp->new(
    timeperiod_name => 'child',
    alias           => 'child',
    sunday          => '00:01-23:01'
);

is( $next->use, '24x7', "child object should know its parent's name" );
isa_ok( $next, 'Nagios::Object' );

