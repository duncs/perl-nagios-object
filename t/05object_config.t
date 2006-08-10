#!/usr/bin/perl -w
use strict;
use Test::More qw(no_plan);
use lib qw( ../lib ./lib );

use_ok( 'Nagios::Object::Config' );

ok( my $parser = Nagios::Object::Config->new(), "\$parser = Nagios::Object::Config->new()" );

ok( $parser->parse( 't/testconfig.cfg' ), "\$parser->parse( 't/testconfig.cfg' )" );

ok( $parser->resolve_objects, "\$parser->resolve_objects" );
ok( $parser->register_objects, "\$parser->register_objects" );

ok( $parser->resolve_objects, "\$parser->resolve_objects should be ok to call multiple times" );
ok( $parser->register_objects, "\$parser->register_objects should be ok to call multiple times" );

ok( my @hosts = $parser->list_hosts(), "\$parser->list_hosts()" );

