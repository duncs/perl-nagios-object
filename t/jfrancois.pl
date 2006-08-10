#!/usr/local/bin/perl

=pod

Hi !

I'm trying to use the Nagios::Config module, but I am obviously doing something wrong as I cannot get any result with the find_object( ) method - despite the fact that the host exist in my config files.

========================= 

=cut

use lib qw( ../lib ./lib );
use Nagios::Object;
use Nagios::Object::Config;
use Nagios::Config;
use Text::CSV;
use strict;

my $conffile = "jfrancois.cfg";

print "Test 1:\n";
my $nagios=Nagios::Config->new ( Filename => $conffile, Version => 1 );
$nagios->parse( $conffile );

use Data::Dumper;

# Parse existing Nagios configuration files
#my $nagios= Nagios::Config->new( Version => 1.2 );
$nagios->resolve_objects();
$nagios->register_objects();

# Get an existing host
my $test_host= $nagios->find_object("debian-master", 'Nagios::Host' );
if ( $test_host ) {
    my $name = $test_host->host_name;
    my $address = $test_host->address;

    print "\tmy name is $name\n";
    print "\tmy address is $address\n";
    print "\tDumping ... (\$test_host->dump())\n\n";
    print $test_host->dump(); 
}

=pod

=========================
The print above yeld the following result :
my  name is
my address is
define host {
}

The host "debian-master" definition is as follow :
Define host{
        use                     generic-host-ext
        host_name               debian-master
        alias                   Debian Master
        parents                 PC0534
        address                 <an IP address>
        notification_period     workhours
        }

Where generic-host-ext is a template extended from generic-host.
The Nagios setup is working correctly
The parsing of the nagios.cfg file seems ok, as it takes some time to process.
I also tried using Nagios::Object::Config directly, with equal result.
I tried to register and resolve $test_host, but it doesn't seems to change anything.

If you would like to know the bigger picture, I'm building a script which use Nagios::Config and Text::CVS to parse existing Nagios configuration files and a CSV file.

The CSV file contains basic information about the host we want to monitor (IP address, SNMP community, service we want to be monitored etc.).

The script would make / update the existing nagios configuration file automatically, provided a correct CSV file.
It would dramaticaly help the integration process in a production environment - indeed it's the latest step before I put Nagios servers in.

I googled a lot to find working examples of Nagios::Config, but not find anything apart cpan doc. If you have some URL / mailing list / forum which can help me with this problem, I would be gratefull : )

Thanks for your help

Jean François 

=cut

=pod

MASURE Jean-Francois 	
to me
	 More options	  7/13/05
Thanks for your time.

I can proceed without find_object() with this small workaround :

========

=cut

print "\n\nTest2:\n";

 my $host = undef;
 my @hostlist = $nagios->list_hosts();
 foreach my $h (@hostlist)
 {
   if ($h->name() eq "debian-master")
   {
     $host = $h;
     last;                                             # found it, abort foreach {}
   }
 }

 if ( $host = undef )
 {
   print "cannot found debian-master\n";
 }
 else {
    print "found debian-master: $host\n";
 }

=pod

========

It might be less effective than a find_object ( O(n) ) but it gets the job done ;)

=cut

