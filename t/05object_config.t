#!/usr/bin/perl -w

# File ID: $Id$
# Last Change: $LastChangedDate$
# Revision: $Rev$

use strict;
use Test::More qw(no_plan);
use Data::Dumper;
use lib qw( ../lib ./lib );

eval { chdir('t') };

use_ok( 'Nagios::Object::Config' );

ok( my $parser = Nagios::Object::Config->new(), "\$parser = Nagios::Object::Config->new()" );

ok( $parser->parse( 'testconfig.cfg' ), "\$parser->parse( 'testconfig.cfg' )" );

ok( $parser->resolve_objects, "\$parser->resolve_objects" );
ok( $parser->register_objects, "\$parser->register_objects" );

ok( $parser->resolve_objects, "\$parser->resolve_objects should be ok to call multiple times" );
ok( $parser->register_objects, "\$parser->register_objects should be ok to call multiple times" );

ok( my @hosts = $parser->list_hosts(), "\$parser->list_hosts()" );
ok( my @contacts = $parser->list_contacts(), "\$parser->list_contacts()" );
#warn Dumper(\@contacts);
#

