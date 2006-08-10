#!/usr/bin/perl -w
use strict;
use lib qw( ./lib ../lib /home/tobeya/work/lib );
use Nagios::Config;
use Nagios::Object::Config;
use Getopt::Std;
use Benchmark qw(:all);
use Data::Dumper;

our( $opt_n, $opt_o, $opt_v, $opt_b, $opt_d, $opt_f, $opt_r );
getopt( 'n:o:v:' );
getopt( 'bdfr' );

if ( $opt_f ) {
    Nagios::Config->fast_mode(1);
}

if ( !$opt_n && !$opt_o ) {
    print "Must specify a filename to parse (either -n or -o).\n";
    exit 1;
}

my $t0 = new Benchmark;

my $obj = undef;
if ( $opt_n ) {
    $obj = Nagios::Config->new( Filename => $opt_n, Version => $opt_v );
}
if ( $opt_o ) {
    $obj = Nagios::Object::Config->new( Version => $opt_v );
    $obj->parse( $opt_o );

    if ( $opt_r ) {
        $obj->resolve_objects;
        $obj->register_objects;
    }
}

if ( $opt_d ) {
    print Dumper($obj), "\n";
}

if ( $opt_b ) {
    my $t1 = new Benchmark;
    my $td = timediff( $t1, $t0 );
    printf "Benchmark: %s\n", timestr($td);
}

=head1 NAME

parse.pl

=head1 USAGE

parse.pl [-n|-o] [-v] [-b] [-d] [-f]

=head1 OPTIONS

=over 4

=item -n

Specify a primary nagios configuration file.  This file will be parsed along with
any object configuration files referenced inside it.

=item -o

Parse a single object configuration file.

=item -v

Specify a Nagios configuration version to parse. i.e. -v 1 or -v 2

=item -b

Show some benchmarking information.

=item -d

Dump out the data structures after parsing (uses Data::Dumper).

=item -f

Use the new EXPERIMENTAL fast mode.

=cut

