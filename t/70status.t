#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 8;
use Test::NoWarnings;
use Test::Exception;

use lib qw( ../lib ./lib );
use Nagios::StatusLog;

( my $filename = $0 ) =~ s/t$/dat/;

my $log = Nagios::StatusLog->new(
    Filename => $filename,
    Version  => 3,
);

isa_ok( $log, 'Nagios::StatusLog' );

my $admin_contact = $log->contact("admin");
isa_ok( $admin_contact, "Nagios::Contact::Status" );
is_deeply( $admin_contact, {
    contact_name => "admin",
    host_notification_period => "24x7",
    host_notifications_enabled => 1,
    last_host_notification => 0,
    last_service_notification => 0,
    modified_attributes => 0,
    modified_host_attributes => 0,
    modified_service_attributes => 0,
    service_notification_period => "24x7",
    service_notifications_enabled => 1,
    }, "Attributes for admin right" );

my $admin2 = $log->contact("admin2");
isa_ok( $admin2, "Nagios::Contact::Status");
is_deeply( $admin2, {
    contact_name => "admin2",
    host_notification_period => "24x7",
    host_notifications_enabled => 1,
    last_host_notification => 1,
    last_service_notification => 0,
    modified_attributes => 0,
    modified_host_attributes => 0,
    modified_service_attributes => 0,
    service_notification_period => "24x7",
    service_notifications_enabled => 1,
    }, "Attributes for admin right" );


my $host = $log->host("doesnt_exist_1");
my $hostattrs = attributes_hash($host);
is_deeply( $hostattrs, { 
         'acknowledgement_type' => 0,
         'active_checks_enabled' => 1,
         'check_command' => 'check_host_15!-H $HOSTADDRESS$ -t 3 -w 500.0,80% -c 1000.0,100%',
         'check_execution_time' => 3.186,
         'check_interval' => "0.000000",
         'check_latency' => 0.067,
         'check_options' => 0,
         'check_period' => '',
         'check_type' => 0,
         'current_attempt' => 1,
         'current_event_id' => 31,
         'current_notification_id' => 553,
         'current_notification_number' => 46,
         'current_problem_id' => 18,
         'current_state' => 2,
         'event_handler' => '',
         'event_handler_enabled' => 0,
         'failure_prediction_enabled' => 1,
         'flap_detection_enabled' => 1,
         'has_been_checked' => 1,
         'host_name' => 'doesnt_exist_1',
         'is_flapping' => 0,
         'last_check' => 1233216743,
         'last_event_id' => 24,
         'last_hard_state' => 2,
         'last_hard_state_change' => 1233216701,
         'last_notification' => 1233911011,
         'last_problem_id' => 0,
         'last_state_change' => 1233216701,
         'last_time_down' => 1231947569,
         'last_time_unreachable' => 1231947633,
         'last_time_up' => 1231947413,
         'last_update' => 1233914050,
         'long_plugin_output' => '',
         'max_attempts' => 2,
         'modified_attributes' => 1,
         'next_check' => 0,
         'next_notification' => 1233914611,
         'no_more_notifications' => 0,
         'notification_period' => '24x7',
         'notifications_enabled' => 1,
         'obsess_over_host' => 0,
         'passive_checks_enabled' => 1,
         'percent_state_change' => "0.00",
         'performance_data' => 'rta=0.000ms;500.000;1000.000;0; pl=100%;80;100;;',
         'plugin_output' => 'CRITICAL - 192.168.50.10: rta nan, lost 100% with {}',
         'problem_has_been_acknowledged' => 0,
         'process_performance_data' => 1,
         'retry_interval' => "1.000000",
         'scheduled_downtime_depth' => 0,
         'should_be_scheduled' => 0,
         'state_type' => 1,
 }, "Host attributes correct" );


my $service = $log->service( "doesnt_exist_1", "TCP/IP" );
my $serviceattrs = attributes_hash( $service );
is_deeply( $serviceattrs, {
               'acknowledgement_type' => 0,
            'active_checks_enabled' => 1,
            'check_command' => 'check_icmp!-H $HOSTADDRESS$ -w 100.0,20% -c 500.0,60%',
            'check_execution_time' => 3.677,
            'check_interval' => "5.000000",
            'check_latency' => 0.218,
            'check_options' => 0,
            'check_period' => '24x7',
            'check_type' => 0,
            'current_attempt' => 1,
            'current_event_id' => 23,
            'current_notification_id' => 0,
            'current_notification_number' => 0,
            'current_problem_id' => 17,
            'current_state' => 2,
            'event_handler' => '',
            'event_handler_enabled' => 1,
            'failure_prediction_enabled' => 1,
            'flap_detection_enabled' => 1,
            'has_been_checked' => 1,
            'host_name' => 'doesnt_exist_1',
            'is_flapping' => 0,
            'last_check' => 1233914007,
            'last_event_id' => 0,
            'last_hard_state' => 2,
            'last_hard_state_change' => 1233216735,
            'last_notification' => 0,
            'last_problem_id' => 0,
            'last_state_change' => 1233216735,
            'last_time_critical' => 1233914007,
            'last_time_ok' => 1231947411,
            'last_time_unknown' => 0,
            'last_time_warning' => 0,
            'last_update' => 1233914050,
            'long_plugin_output' => 'IOS (tm) 7200 Software (C7200-P-M), Version 12.2(14)S5, EARLY DEPLOYMENT RELEASE SOFTWARE (fc2)\nTAC Support: http://www.cisco.com/tac\nCopyright (c) 1986-2003 by cisco Systems, Inc.\nCompiled Fri 26-Sep-03 1\n',
            'max_attempts' => 3,
            'modified_attributes' => 1,
            'next_check' => 1233914307,
            'next_notification' => 0,
            'no_more_notifications' => 0,
            'notification_period' => '24x7',
            'notifications_enabled' => 1,
            'obsess_over_service' => 0,
            'passive_checks_enabled' => 1,
            'percent_state_change' => "0.00",
            'performance_data' => 'rta=0.000ms;100.000;500.000;0; pl=100%;20;60;;',
            'plugin_output' => 'CRITICAL - 192.168.50.10: rta nan, lost 100%',
            'problem_has_been_acknowledged' => 0,
            'process_performance_data' => 1,
            'retry_interval' => "1.000000",
            'scheduled_downtime_depth' => 0,
            'service_description' => 'TCP/IP',
            'should_be_scheduled' => 1,
            'state_type' => 1,
}, "service attributes okay" );

sub attributes_hash {
    my $host = shift;
    my %attrs = %$host;
    delete $attrs{__parent};
    \%attrs;
}
