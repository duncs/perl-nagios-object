#!/usr/bin/perl -w

use lib qw( ../lib ./lib );
use Test::More qw(no_plan);
use Test::NoWarnings;

use_ok('Nagios::Object');

can_ok( 'Nagios::Host', 'host_name' );
can_ok( 'Nagios::Host', 'new' );

my $timetxt = '00:00-09:00,17:00-24:00';
ok( my $timerange = Nagios::Object::parse_time_range($timetxt),
    "parse_time_range( $timetxt )" );
ok( eq_array( $timerange, [ [ 0, 32400 ], [ 61200, 86400 ] ] ),
    "verify data returned by parse_time_range" );

diag("creating a Nagios::TimePeriod object ...") if ( $ENV{TEST_VERBOSE} );
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

diag("creating a Nagios::Command object ...") if ( $ENV{TEST_VERBOSE} );
my $cmd = Nagios::Command->new(
    command_name => 'Test',
    command_line => '/bin/true'
);
isa_ok( $cmd, 'Nagios::Object' );

diag("creating a Nagios::Contact object ...") if ( $ENV{TEST_VERBOSE} );
my $contact = Nagios::Contact->new(
    contact_name                  => "testuser",
    alias                         => "The Testing User",
    host_notification_period      => $tp,
    service_notification_period   => $tp,
    host_notification_options     => [qw(d u r n)],
    service_notification_options  => [qw(w u c r n)],
    host_notification_commands    => $cmd,
    service_notification_commands => $cmd,
    email                         => 'testuser@localhost',
    pager                         => '5555555555'
);

diag("creating a Nagios::ContactGroup object ...") if ( $ENV{TEST_VERBOSE} );
my $cg = Nagios::ContactGroup->new(
    alias             => 'A Test Contact Group',
    contactgroup_name => 'testgroup',
    members           => [$contact]
);

diag("creating a Nagios::Host object ...") if ( $ENV{TEST_VERBOSE} );
my $host = Nagios::Host->new(
    host_name                    => 'localhost',
    alias                        => 'localhost',
    address                      => '127.0.0.1',
    parents                      => undef,
    check_command                => 'check-host-alive',
    max_check_attempts           => 3,
    checks_enabled               => 1,
    event_handler                => 'command_name',
    event_handler_enabled        => 0,
    low_flap_threshold           => 0,
    high_flap_threshold          => 0,
    flap_detection_enabled       => 0,
    process_perf_data            => 1,
    retain_status_information    => 1,
    retain_nonstatus_information => 1,
    notification_interval        => 120,
    notification_options         => [qw(d u r)],
    notifications_enabled        => 1,
    stalking_options             => [qw(o d u)]
);
isa_ok( $host, 'Nagios::Object' );

can_ok( $host, 'host_name' );
is( $host->host_name(), 'localhost',
    "Nagios::Host->host_name() returns correct value" );

can_ok( $host, 'set_alias' );
can_ok( $host, 'alias' );
ok( $host->set_alias("bar"), "Nagios::Host->set_alias() works" );
is( $host->alias(), "bar",
    "Nagios::Host->alias() returns value set by previous test" );

diag("\ntesting templates ...\n\n") if ( $ENV{TEST_VERBOSE} );

diag("creating service template ...") if ( $ENV{TEST_VERBOSE} );
my $template = Nagios::Service->new(
    register                     => 0,
    host                         => $host,
    description                  => 'Test::More',
    is_volatile                  => 0,
    check_command                => $cmd,
    max_check_attempts           => 1,
    normal_check_interval        => 1,
    retry_check_interval         => 1,
    active_checks_enabled        => 1,
    passive_checks_enabled       => 1,
    check_period                 => $tp,
    parallelize_check            => 1,
    obsess_over_service          => 1,
    check_freshness              => 1,
    freshness_threshhold         => 5,
    event_handler                => $cmd,
    event_handler_enabled        => 1,
    low_flap_threshhold          => 3,
    high_flap_threshhold         => 5,
    flap_detection_enabled       => 1,
    process_perf_data            => 1,
    retain_status_information    => 1,
    retain_nonstatus_information => 1,
    notification_interval        => 120,
    notification_options         => [qw(u w c r)],
    contact_groups               => [],
    notifications_enabled        => 1,
    stalking_options             => [qw(o w u c)]
);
isa_ok( $template, 'Nagios::Object' );

foreach my $pkg (
    qw( Service Host HostGroup Contact ContactGroup Command TimePeriod ServiceEscalation ServiceDependency HostEscalation HostDependency HostGroupEscalation )
    )
{
    my $fqpkg = 'Nagios::' . $pkg;
    ok( my $object = $fqpkg->new(), "$fqpkg->new()" );
    my $vfref;
UGLY: {
        no strict 'refs';
        $vfref = ${ $fqpkg . '::valid_fields' };
    }

    # make sure all objects have all the methods defind for their attributes
    # - these are the compile-time created methods
    foreach my $method ( keys(%$vfref) ) {
        can_ok( $object, $method );
        $object->$method();
        can_ok( $object, "set_$method" );
    }

    # make sure all objects can call the "regular" methods
    foreach my $method (
        qw( list_attributes attribute_type attribute_is_list name ))
    {
        can_ok( $object, $method );
    }

    # make sure ->name returns the right data for an object
    #foreach my $pkg
}

ok( my $empty_cmd = Nagios::Object->new( Type => 'Nagios::Command' ),
    "Nagios::Object->new( Type => Nagios::Command )" );
can_ok( $empty_cmd, 'set_command_name' );

ok( my $empty_tp = Nagios::Object->new( Type => 'Nagios::TimePeriod' ),
    "Nagios::Object->new( Type => Nagios::TimePeriod )" );
can_ok( $empty_tp, 'timeperiod_name' );
can_ok( $empty_tp, 'set_timeperiod_name' );
ok( $empty_tp->set_timeperiod_name("foobar"),
    "\$object->set_timeperiod_name"
);
is( $empty_tp->timeperiod_name, 'foobar', "\$object->timeperiod_name" );
is( $empty_tp->name,            'foobar', "\$object->name" );

