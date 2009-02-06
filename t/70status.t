#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;

use lib qw( ../lib ./lib );
use Nagios::StatusLog;

my $host = 'localhost';

( my $filename = $0 ) =~ s/t$/dat/;

my $log = Nagios::StatusLog->new(
    Filename => $filename,
    Version  => 3,
);

isa_ok($log, 'Nagios::StatusLog');
