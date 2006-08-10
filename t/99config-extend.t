#!/usr/local/bin/perl -w
use strict;
use Test::More qw(no_plan);
use lib qw( ../lib ./lib );

use_ok( 'Nagios::Object' );


package Nagios::Host;
{
    no warnings; # so use of valid_fields doesn't bug us
    $Nagios::Host::valid_fields->{snmp_community} = [ 'STRING', 0, 0, 0 ];
}
sub snmp_community { shift->{snmp_community}->() || 'public' }
sub set_snmp_community {
    my $self = shift;
    if ( !exists($self->{snmp_community}) ) {
        $self->{snmp_community} = 'public';
    }
    $self->_set('snmp_community', @_);
}

#sub set_snmp_community { $_[0]->{snmp_community} = $_[1] }

package main;

can_ok( 'Nagios::Host', 'snmp_community' );
can_ok( 'Nagios::Host', 'set_snmp_community' );

my $host = Nagios::Host->new();

can_ok( $host, 'snmp_community' );
can_ok( $host, 'set_snmp_community' );

ok( $host->set_snmp_community( "guessme" ),
    "newly created set_snmp_community method works" );
is( $host->snmp_community, 'guessme',
    "use getter method to verify previous test" );

