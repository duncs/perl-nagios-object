#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use lib qw( ../lib ./lib );

BEGIN { plan tests => 2 }

use Nagios::Object::Config;
use List::Compare;
#use Data::Dumper;
#$Data::Dumper::Maxdepth = 3;

my $file = 'service_escalation.cfg';

eval { chdir('t'); };

sub _host_list {
	my ($self, $method, $h) = @_;
	if ( $self->can($method) ) {
		if ( ref $self->$method eq 'ARRAY' ) {
			map {
				if ( ref $_ eq '' ) {
					$h->{$_}++;
				} else {
					$h->{$_->host_name}++;
				}
			} @{$self->$method};
		} elsif ( defined $self->$method ) {
			$h->{ $self->$method }++;
		}
	}
}
sub get_host_list {
	my ($self, $obj) = @_;
	my %h;
	&_host_list($self, 'host_name', \%h);
	if ( $self->can('hostgroup_name') ) {
		if ( ref $self->hostgroup_name eq 'ARRAY' ) {
			foreach my $hg ( @{$self->hostgroup_name} ) {
				my $hg2 = ( ref $hg eq ''
					? $obj->find_object($hg, 'Nagios::HostGroup')
					: $hg);
				&_host_list($hg2, 'members', \%h);
			}
		} elsif ( defined $self->hostgroup_name ) {
			my $hg2 = ( ref $self->hostgroup_name eq ''
				? $obj->find_object($self->hostgroup_name, 'Nagios::HostGroup')
				: $self->hostgroup_name);
			&_host_list($hg2, 'members', \%h);
		}
	}
	return keys %h;
}

my $obj = Nagios::Object::Config->new();
$obj->parse($file) || die "Could not parse object file ($file)\n";
$obj->resolve_objects();
$obj->register_objects();

foreach my $esc ( @{$obj->list_serviceescalations()} ) {

	my $svc = $esc->service_description;

	my @esc_hosts = &get_host_list($esc, $obj);
	my @svc_hosts = &get_host_list($svc, $obj);

	my ($lc) = List::Compare->new(\@esc_hosts, \@svc_hosts);

	ok( scalar @esc_hosts && scalar @svc_hosts && $lc->is_LequivalentR(), "Matching host lists between a service and serviceescalation");
}

exit 0;
