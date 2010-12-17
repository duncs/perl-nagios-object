#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use lib qw( ../lib ./lib );

BEGIN { plan tests => 3 }

use Nagios::Object::Config;

my $err = 0;
my $file = 'find_object-template.cfg';

my @types = qw/Nagios::ServiceEscalation Nagios::HostEscalation Nagios::ServiceDependency/;
my @methods = qw/list_serviceescalations list_hostescalations list_servicedependencies/;

eval { chdir('t'); };

my $obj = Nagios::Object::Config->new();
$obj->parse($file) || die "Could not parse object file ($file)\n";
$obj->resolve_objects();

for (my $i = 0; $i < scalar @types; $i++) {
	my $method = $methods[$i];
	foreach my $o ( @{$obj->$method()} ) {
		# If we have use a template, find that object.
		if ( exists $o->{'use'} && defined $o->{'use'} ) {
			my $res = $obj->find_object($o->{'use'}, $types[$i]);
			my $ref = ref $res;
			ok( $ref eq $types[$i], "Looking for a $types[$i] object" );
		}
	}
}

exit $err;
