#!/usr/bin/perl

use strict;
use Test::More qw(no_plan);
use Test::NoWarnings;
use File::Temp qw(tempfile);
use Data::Dumper;
use Scalar::Util qw(blessed);
use lib qw( ./lib ../lib );
eval { chdir('t') };
$Data::Dumper::Deparse = 1;

use_ok( 'Nagios::Object' );

my %test_host = (
      host_name                    => 'localhost',
      alias                        => 'localhost',
      address                      => '127.0.0.1',
      check_command                => 'check-host-alive',
      max_check_attempts           => 3,
      checks_enabled               => 1,
      event_handler                => 'command_name',
      event_handler_enabled        => 0,
      low_flap_threshold          => 0,
      high_flap_threshold         => 0,
      flap_detection_enabled       => 0,
      process_perf_data            => 1,
      retain_status_information    => 1,
      retain_nonstatus_information => 1,
      notification_interval        => 120,
      notification_options         => [qw(d u r)],
      notifications_enabled        => 1,
      stalking_options             => [qw(o d u)]
);

diag( "create a test Nagios::Host object" ) if ( $ENV{TEST_VERBOSE} );
my $host = Nagios::Host->new( %test_host );

ok( my $dump1 = $host->dump, "call dump()" );
is( $dump1, $host->dump, "output is consistent across calls to dump()" );

is ( $host->name, $test_host{host_name}, "name() method works as expected" );

use_ok( "Nagios::Object::Config" );

# write the dumped config out to a file
my( $fh, $filename ) = tempfile();
print $fh $dump1;
close $fh;

#warn $dump1;

my $config = Nagios::Object::Config->new();
$config->parse( $filename );

#warn Dumper($config);
ok( my $file_host = $config->find_object( $test_host{host_name} ),
    "Retrieve the object from the parsed configuration." );

isnt( "$host", "$file_host", "parsed object is not a copy" );

foreach my $key ( sort keys %test_host ) {
    is_deeply( $host->$key, $file_host->$key, "$key matches" );
}


# test for rt#17945
my $some_command = "foo";
my $timeperiod = 5;

my $generic_host = Nagios::Host->new(
register => 0,
parents => undef,
check_command => $some_command,
max_check_attempts => 3,
checks_enabled => 1,
event_handler => $some_command,
event_handler_enabled => 0,
low_flap_threshold => 0,
high_flap_threshold => 0,
flap_detection_enabled => 0,
process_perf_data => 1,
retain_status_information => 1,
retain_nonstatus_information => 1,
notification_interval => $timeperiod,
notification_options => [qw(d u r)],
notifications_enabled => 1,
stalking_options => [qw(o d u)]
);
isa_ok($generic_host, 'Nagios::Host');

ok( $generic_host->dump(), "rt#17945 - dump ok");;

