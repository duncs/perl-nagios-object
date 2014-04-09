#!/usr/local/bin/perl

# $Id$
# $LastChangedDate$
# $Rev$

use lib qw(./lib ../lib);
use Nagios::StatusLog;
use Benchmark ':hireswallclock';
use Getopt::Std;
use Data::Dumper;

=head1 NAME

statusdat_demo.pl - test the StatusLog module

=head1 USAGE

perl statusdat_demo.pl -l /var/opt/nagios/status.dat -v 2

=head1 NOTES

Please send the benchmark outputs to duncs@cpan.org so I can see how the 
performance is on boxes and configs other than my own.

=cut

our $opt_l;
our $opt_v;
getopt('l:v:');

if ( !$opt_l || !$opt_v ) {
    die
        "Must specify:\n Location of Nagios status log with -l option.\n Nagios Version with -v option\n";
}

my $bench_begin = Benchmark->new;
my $log = Nagios::StatusLog->new( Filename => $opt_l, Version => $opt_v );

my $bench_postparse = Benchmark->new;

#print Dumper( $log );

foreach my $host ( $log->list_hosts ) {
    my $obj = $log->host($host);
    printf "Host: %s Last Update: %d\n", $obj->host_name, $obj->last_update;

}

my $prog = $log->program;
printf "Started at %d", $prog->program_start;

my $bench_postprint = Benchmark->new;

printf "\nTime to parse: %s\nTime to print: %s\n\n",
    timestr( timediff( $bench_postparse, $bench_begin ) ),
    timestr( timediff( $bench_postprint, $bench_postparse ) );

