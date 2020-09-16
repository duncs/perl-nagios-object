#!/usr/bin/perl -w

use strict;
use Test::More qw(no_plan);
use Test::NoWarnings;
use lib qw( ../lib ./lib );
use Data::Dumper;

$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;

eval { chdir('t') };

use Nagios::Config;

my $config = Nagios::Object::Config->new();
$config->parse('additive_inheritance.cfg');

my $host = $config->find_object('linuxserver1','Nagios::Host');
is(Dumper([$host->hostgroups]),q{[['all-servers','linux-servers','web-servers']]});

