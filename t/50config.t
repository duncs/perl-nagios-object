#!/usr/local/bin/perl

use strict;
use Test::More qw(no_plan);
use Test::NoWarnings;
use Test::Exception;
use lib qw( ./lib ../lib );
#BEGIN { plan tests => 7; }
eval { chdir('t') };

use_ok( 'Nagios::Config' );

ok( my $cf = Nagios::Config->new(Filename => "nagios.cfg"),
    "Nagios::Config->new()" );

diag( "run tests to make sure inherited Nagios::Config::File methods work" ) if ( $ENV{TEST_VERBOSE} );

is( $cf->get('command_check_interval'), '15s',
    "get('command_check_interval') returns 15s" );

is( $cf->get('downtime_file'), $cf->get_attr('downtime_file'),
    "make sure get_attr from v0.02 still works" );

ok( my $list = $cf->get('cfg_file'), "get('cfg_file')" );

is( ref($list), 'ARRAY',
    "getting an attribute that allows multiples returns an arrayref" );

ok( @$list > 2, "arrayref from previous test has more than two elements" );

diag( "run tests to make sure inherited Nagios::Config::Object methods work" ) if ( $ENV{TEST_VERBOSE} );

ok( $cf->resolve_objects, "\$parser->resolve_objects should be ok to call multiple times" );
ok( $cf->register_objects, "\$parser->register_objects should be ok to call multiple times" );

ok( my @hosts = $cf->list_hosts(), "\$parser->list_hosts()" );

lives_ok( sub {
    my $mf_cf = Nagios::Config->new(
        Filename => 'nagios-missing-file.cfg',
        allow_missing_files => 1
    );
}, "parameter allow_missing_files lets new() live through missing files" );

