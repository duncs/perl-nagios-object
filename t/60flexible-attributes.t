#!/usr/bin/perl -w

use strict;
use Test::More qw(no_plan);
use Test::Exception;
use Scalar::Util qw(blessed);
use lib qw( ../lib ./lib );
use Data::Dumper;

eval { chdir('t') };

use Nagios::Config;

my $lax = Nagios::Object::Config->new();
lives_ok( sub { $lax->parse('60flexible-attributes1.cfg') }, "parse() does not throw exceptions by default" );

my @contacts = $lax->list_contacts;
lives_ok( sub { $contacts[0]->random_one }, "Verify that get method was instantiated" );
lives_ok( sub { $contacts[0]->set_random_one('foobar') }, "Verify that set method was instantiated" );

# enable strict mode
Nagios::Object::Config->strict_mode(1);
my $strict = Nagios::Object::Config->new();
dies_ok( sub { $strict->parse('60flexible-attributes2.cfg') }, "parse() throws exceptions with strict_mode" );

dies_ok( sub { $contacts[0]->random_four }, "verify that no methods were instantiated under strict_mode" );

