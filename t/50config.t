use strict;
use Test::More qw(no_plan);
use lib qw( ./lib ../lib );
#BEGIN { plan tests => 7; }

use_ok( 'Nagios::Config' );

ok( my $cf = Nagios::Config->new(Filename => "t/nagios.cfg"),
    "Nagios::Config->new()" );

diag( "run tests to make sure inherited Nagios::Config::File methods work" );

is( $cf->get('command_check_interval'), '15s',
    "get('command_check_interval') returns 15s" );

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

