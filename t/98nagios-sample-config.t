#!/usr/local/bin/perl

use strict;
use File::Temp qw( tempfile );
use Test::More qw(no_plan);
use Data::Dumper;
use Scalar::Util qw(blessed);
use lib qw( ./lib ../lib );
#BEGIN { plan tests => 7; }
eval { chdir('t') };

use_ok( 'Nagios::Config' );
use_ok( 'Nagios::Object::Config' );

# make sure tests fail if Nagios::Object does not recognize attributes/objects
# in the sample configs
Nagios::Object::Config->strict_mode( 1 );

my @sample_files = qw(
    sample-config-bigger.cfg
    sample-config-minimal.cfg
    sample-config-v3.cfg
);

foreach my $file ( @sample_files ) {
    diag( "testing with Nagios sample file $file ..." ) if ( $ENV{TEST_VERBOSE} );
	my $parser = Nagios::Object::Config->new( Version => '2.0' );
	$parser->parse( $file );
	
	ok( $parser->resolve_objects, "\$parser->resolve_objects" );
	ok( $parser->register_objects, "\$parser->register_objects" );

    my $all_objects = $parser->all_objects;
    foreach my $object ( @$all_objects ) {
        ok( $object->dump, 'dump '.ref($object). ' named '. $object->name );
    }
}

