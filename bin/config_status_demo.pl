#!/usr/local/bin/perl

use lib qw( /home/tobeya/work/CPAN/Nagios-Objects/lib );
use Nagios::Config;
use Nagios::StatusLog;
use Benchmark ':hireswallclock';
use Getopt::Std;

=head1 NAME

config_status_demo.pl - demonstrate using Nagios::Config and Nagios::StatusLog together.

=head1 USAGE

perl config_status_demo.pl -c /etc/opt/nagios/nagios.cfg -l /var/opt/nagios/status.log

=head1 NOTES

Please send the benchmark outputs to tobeya@cpan.org so I can see how the performance
is on boxes and configs other than my own.

This setup is very sensitive to mistmatches between the configuration and the status log.

=cut

our( $opt_c, $opt_l ) = ();
getopt( 'c:l:' );
die "Must specify location of Nagios configuration with -c option."
    if ( !$opt_c );
die "Must specify location of Nagios status log with -l option."
    if ( !$opt_l );

my $bench1 = Benchmark->new;
my $cf = Nagios::Config->new( $opt_c );

my $bench2 = Benchmark->new;
my $log = Nagios::StatusLog->new( $opt_l );

my $bench10 = Benchmark->new;
foreach my $h ( $cf->list_hosts ) {
    next if ( !length $h->host_name ); # avoid a bug in Nagios::Object
    foreach my $s ( $h->list_services ) {
        my $svcs = $log->service( $h, $s );
        if ( $svcs->status ne 'OK' ) { # only print for service not in OK
                                       # comment out the if () { } to print everything 
            printf "Service %s on %s has status of %s\n",
               $s->service_description,
               $h->host_name,
               $svcs->status;
        }
    }
}
my $bench11 = Benchmark->new;

printf "\nTime to parse: %s\nTime to parse Logfile: %s\nTime to print: %s\n\n",
        timestr(timediff( $bench2, $bench1 )), 
        timestr(timediff( $bench10, $bench2 )), 
        timestr(timediff( $bench11, $bench10 ));

