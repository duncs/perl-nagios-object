#!/usr/local/bin/perl

use strict;
use Test::More;
use lib qw( ./lib ../lib );
BEGIN { plan tests => 7; }
eval { chdir('t') };

use_ok( 'Nagios::Config::File' );

ok( my $cf = Nagios::Config::File->new("nagios.cfg"),
    "Nagios::Config::File->new()" );

is( $cf->get('command_check_interval'), '15s',
    "get('command_check_interval') returns 15s" );

is( $cf->get('downtime_file'), $cf->get_attr('downtime_file'),
    "make sure get_attr from v0.02 still works" );

ok( my $list = $cf->get('cfg_file'), "get('cfg_file')" );

is( ref($list), 'ARRAY',
    "getting an attribute that allows multiples returns an arrayref" );

ok( @$list > 2, "arrayref from previous test has more than two elements" );


