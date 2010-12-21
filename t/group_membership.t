#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use lib qw( ../lib ./lib );

BEGIN { plan tests => 6 }

use List::Compare;
use Nagios::Object::Config;

my $err = 0;
my $file = 'group_membership.cfg';

eval { chdir('t'); };

my $obj = Nagios::Object::Config->new();
$obj->parse($file) || die "Could not parse object file ($file)\n";
$obj->resolve_objects();
$obj->register_objects();

my @hostgroups = @{$obj->list_hostgroups()};
my @hosts = @{$obj->list_hosts()};

foreach my $h ( @hosts ) {
	my (@hgs) = @{$h->hostgroups};
	my ($lc) = List::Compare->new(\@hostgroups, \@hgs);
	ok( $lc->is_LequivalentR(), "Host " . $h->host_name . " is not listed as a member of all hostgroups.");
}

foreach my $hg ( @hostgroups ) {
	my ($h) = $hg->members;
	my ($lc) = List::Compare->new(\@hosts, $h);
	ok( $lc->is_LequivalentR(), "Hostgroup " . $hg->hostgroup_name . " does not have all hosts listed.");
}

exit $err;
