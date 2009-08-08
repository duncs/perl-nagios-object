#!/usr/local/bin/perl

# File ID: $Id$
# Last Change: $LastChangedDate$
# Revision: $Rev$

use lib qw(./lib ../lib);
use Nagios::Config;
use Nagios::Object::Config;
use Benchmark ':hireswallclock';
use Getopt::Std;

=head1 NAME

test_configuration.pl - Load your configuration to verify Nagios::Object is compatible with it.
  -c: path to your main configuration file
  -l: "relaxed" mode - allow unrecognized attributes on objects, default is strict

=head1 USAGE

perl test_configuration.pl -c /etc/opt/nagios/nagios.cfg
perl test_configuration.pl -l -c /etc/opt/nagios/nagios.cfg

=cut

our $opt_c;
our $opt_l;
getopt('c:l');
die "Must specify location of Nagios configuration with -c option."
    if ( !$opt_c );

unless ($opt_l) {
    Nagios::Object::Config->strict_mode(1);
}

my $bench_start = Benchmark->new;
my $cf = Nagios::Config->new( Filename => $opt_c, force_relative_files => 1 );

my $bench_end = Benchmark->new;

printf "\nTime to parse: %s\n",
    timestr( timediff( $bench_end, $bench_start ) );

