#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';
use Data::Dumper;
use Test::Exception;

use Nagios::Object::Config;
use Nagios::Object;

eval { chdir('t'); };

my $cfile = 'hostgroup_hostgroups.cfg';

my $c;
lives_ok( sub {
    $c = Nagios::Object::Config->new( Version => 2.5 );
}, "new()" );

lives_ok( sub { $c->parse($cfile); }, "Config parse() succeeded for '$cfile'" );
$c->resolve_objects;
$c->register_objects;

ok( my $service = $c->find_object('Current Load'), "Get a service object to work with" );

ok( my $host = $c->find_object( 'anotherhost' ), "Get a host to work with" );
my $host_multi = $host->parents;

#print Dumper($host_multi);

#use B::Deparse;
#my $dp = B::Deparse->new();
#print $dp->coderef2text( \&Nagios::Service::servicegroups );

my $list = $service->servicegroups;

