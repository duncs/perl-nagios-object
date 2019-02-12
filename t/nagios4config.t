#!/usr/local/bin/perl

use strict;
use Test::More;
use Test::NoWarnings;

use lib qw( ./lib ../lib );

BEGIN { plan tests => 17; }
eval { chdir('t') };

use_ok('Nagios::Config');

ok( my $cf = Nagios::Config->new(
        Filename => "v4_config/nagios.cfg",
        Version  => 4
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

my @hostgroups = $cf->list_hostgroups();
ok( @hostgroups, "\$parser->list_hostgroups()" );

# diag ("host groups: " . join(', ', map { $_->hostgroup_name } @hostgroups));
my $linux_servers
    = ( grep { $_->hostgroup_name eq 'linux-servers' } @hostgroups )[0];

ok( defined($linux_servers), "Found linux-servers in configuration" );

# make sure linux-servers has 1 members, which is a host

my $host_members = $linux_servers->members();
ok( scalar(@$host_members) == 1, "linux-servers should have 1 member" );

# diag ("linux-servers members: " . join(', ', map { "[" . join(", ", @{$_} ) . "]" } @$host_members));

{

    sub checkelement {
        my $element = shift;
        my $msg     = shift;

        ok( ref( $element ) eq 'Nagios::Host',
            $msg . " was not a Nagios::Host"
        );
    }

    checkelement( $host_members->[0], "linux-servers first entry" );
}

my @servicegroups = $cf->list_servicegroups();
ok( scalar(@servicegroups) == 0, "\$parser->list_servicegroups()" );
