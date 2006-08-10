#!/usr/local/bin/perl -w
use strict;
use Test::More;
use lib qw( ../lib ./lib );
BEGIN { plan tests => 8 }
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

my %hndls = ( Host => $host, Service => $svc, Program => $pgm );

# broken by current hackery to support Nagios 2.0 status.dat in StatusLog.pm
# subsequent rewrite to AUTOLOAD instead of create at BEGIN should fix this
#foreach my $tag ( qw( Service Host Program ) ) {
#    my $class = "Nagios::${tag}::Status";
#    foreach my $method ( $class->list_tags() ) {
#        can_ok( $hndls{$tag}, $method );
#        ok( length($hndls{$tag}->$method()), "$method non-zero-length output" );
#    }
#}

#$log->write( '/tmp/foo.log' );

exit 0;

