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
$config->parse('multipletemplates.cfg');

my $host = $config->find_object('devweb1','Nagios::Host');

is($host->check_interval, 10, 'attribute defined in both parent templates');
is($host->active_checks_enabled, 1, 'attribute defined in first parent template');
is(Dumper([$host->notification_options]), q{[['d','u','r']]},
   'attribute defined in second parent template');

$host = $config->find_object('linuxserver2','Nagios::Host');
is(Dumper([$host->hostgroups]), q{[['all-servers','linux-servers','web-servers','one']]},
    'multiple additive inheritance');

is($host->alias, undef, 'undefined attribute');
