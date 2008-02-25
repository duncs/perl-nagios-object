#!/usr/local/bin/perl

use strict;
use Test::More;
use lib qw( ./lib ../lib );

BEGIN { plan tests => 12; }
eval { chdir('t') };

use_ok( 'Nagios::Config' );

ok( my $cf = Nagios::Config->new(Filename => "v2_config/nagios.cfg", Version => 2),
    "Nagios::Config->new()" );

diag( "run tests to make sure inherited Nagios::Config::File methods work" );

is( $cf->get('command_check_interval'), '-1',
    "get('command_check_interval') returns -1" );

is( $cf->get('downtime_file'), $cf->get_attr('downtime_file'),
    "make sure get_attr from v0.02 still works" );

ok( my $list = $cf->get('cfg_file'), "get('cfg_file')" );

is( ref($list), 'ARRAY',
    "getting an attribute that allows multiples returns an arrayref" );

ok( @$list > 2, "arrayref from previous test has more than two elements" );

diag( "run tests to make sure inherited Nagios::Config::Object methods work" );

ok( $cf->resolve_objects, "\$parser->resolve_objects should be ok to call multiple times" );
ok( $cf->register_objects, "\$parser->register_objects should be ok to call multiple times" );

ok( my @hosts = $cf->list_hosts(), "\$parser->list_hosts()" );
ok( my @services = $cf->list_hosts(), "\$parser->list_services()" );

ok( my @hostgroups = $cf->list_hostgroups(), "\$parser->list_hostgroups()" );

