#!/usr/local/bin/perl

use strict;
use Test::More;
use Test::NoWarnings;

use lib qw( ./lib ../lib );

BEGIN { plan tests => 25; }
eval { chdir('t') };

use_ok('Nagios::Config');

ok( my $cf = Nagios::Config->new(
        Filename => "v2_config/nagios.cfg",
        Version  => 2
    ),
    "Nagios::Config->new()"
);

diag("run tests to make sure inherited Nagios::Config::File methods work")
    if ( $ENV{TEST_VERBOSE} );

is( $cf->get('command_check_interval'),
    '-1', "get('command_check_interval') returns -1" );

is( $cf->get('downtime_file'),
    $cf->get_attr('downtime_file'),
    "make sure get_attr from v0.02 still works"
);

ok( my $list = $cf->get('cfg_file'), "get('cfg_file')" );

is( ref($list), 'ARRAY',
    "getting an attribute that allows multiples returns an arrayref" );

ok( @$list > 2, "arrayref from previous test has more than two elements" );

diag("run tests to make sure inherited Nagios::Config::Object methods work")
    if ( $ENV{TEST_VERBOSE} );

ok( $cf->resolve_objects,
    "\$parser->resolve_objects should be ok to call multiple times" );
ok( $cf->register_objects,
    "\$parser->register_objects should be ok to call multiple times" );

ok( my @hosts    = $cf->list_hosts(), "\$parser->list_hosts()" );
ok( my @services = $cf->list_hosts(), "\$parser->list_services()" );

ok( my @hostgroups = $cf->list_hostgroups(), "\$parser->list_hostgroups()" );

my @servicegroups = $cf->list_servicegroups();
ok( @servicegroups, "\$parser->list_servicegroups()" );

# diag ("service groups: " . join(', ', map { $_->servicegroup_name } @servicegroups));
my $svcgroup1
    = ( grep { $_->servicegroup_name eq 'svcgroup1' } @servicegroups )[0];

ok( defined($svcgroup1), "Found servicegroup1 in configuration" );

# make sure svcgroup1 has 3 members, each of which is a host/service pair

my $svc_members = $svcgroup1->members();
ok( scalar(@$svc_members) == 3, "Servicegroup1 should have 3 members" );

# diag ("svcgroup1 members: " . join(', ', map { "[" . join(", ", @{$_} ) . "]" } @$svc_members));

{

    sub checkelement {
        my $element = shift;
        my $msg     = shift;

        ok( scalar(@$element) == 2, $msg . " did not have 2 entries" );
        ok( ref( $element->[0] ) eq 'Nagios::Host',
            $msg . " index 0 was not a Nagios::Host"
        );
        ok( ref( $element->[1] ) eq 'Nagios::Service',
            $msg . " index 1 was not a Nagios::Service"
        );
    }

    checkelement( $svc_members->[0], "Servicegroup1 first entry" );
    checkelement( $svc_members->[1], "Servicegroup1 second entry" );
    checkelement( $svc_members->[2], "Servicegroup1 third entry" );
}
