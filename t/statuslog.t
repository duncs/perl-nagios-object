#!/usr/local/bin/perl -w
use strict;
use Test::More;
use lib qw( ../lib ./lib );
BEGIN { plan tests => 19 }
eval { chdir('t') };

use_ok( 'Nagios::StatusLog' );

my $config = 'status.log';
ok( my $log = Nagios::StatusLog->new( $config ), "new()" );
ok( $log->update(), "update()" );

ok( my $host = $log->host('spaceghost'), "->host()" );
ok( my $svc  = $log->service('localhost','SSH'), "->service()" );
ok( my $pgm  = $log->program(), "->program()" );

is( $host->host_name(), 'spaceghost', "\$host->host_name() returns correct value" );
is( $svc->description(), 'SSH', "\$svc->description() returns correct value" );

my $v2logfile = 'v2log.dat';

ok( my $v2log = Nagios::StatusLog->new( Filename => $v2logfile, Version => '2.4' ), "new()" );
can_ok( $v2log, qw(host service program info) );

ok( my $i = $v2log->info, "info()" );
ok( my @services = $v2log->list_services(), "list_services()" );
ok( @services > 0, "More then 0 services." );
ok( my $h = $v2log->host( 'localhost' ), "host()" );
ok( my $s = $v2log->service('localhost', $services[0]), "service()" );
ok( grep {/The Last Service/} @services, "Got the last service in the file" );

# spot check
can_ok( $h, qw( host_name status check_command ) );
ok( $h->status, "status returns a non-null value" );
can_ok( $s, qw( host_name service_description last_time_ok ) );

exit 0;

