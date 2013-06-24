###########################################################################
#                                                                         #
# Nagios::Object                                                          #
# Maintained by Duncan Ferguson <duncs@cpan.org>                          #
# Written by Albert Tobey <tobeya@cpan.org>                               #
# Copyright 2003-2009, Albert P Tobey                                     #
# Copyright 2009, Albert P Tobey and Duncan Ferguson                      #
#                                                                         #
# This program is free software; you can redistribute it and/or modify it #
# under the terms of the GNU General Public License as published by the   #
# Free Software Foundation; either version 2, or (at your option) any     #
# later version.                                                          #
#                                                                         #
# This program is distributed in the hope that it will be useful, but     #
# WITHOUT ANY WARRANTY; without even the implied warranty of              #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       #
# General Public License for more details.                                #
#                                                                         #
###########################################################################
package Nagios::Object;
use warnings;
use strict qw( subs vars );
use Carp;
use Exporter;
use Data::Dumper;
use Scalar::Util qw(blessed);
@Nagios::Object::ISA = qw( Exporter );

# NOTE: due to CPAN version checks this cannot currently be changed to a
# standard version string, i.e. '0.21'
our $VERSION   = '47';
our $pre_link  = undef;
our $fast_mode = undef;
our %nagios_setup;

# constants for flags in %nagios_setup
# note: might ditch version stuff soon (atobey, 2008-02-24)
sub NAGIOS_NO_INHERIT { 1 << 1 }    # cannot inherit from template
sub NAGIOS_PERL_ONLY  { 1 << 2 }    # perl module only attribute
sub NAGIOS_V1         { 1 << 3 }    # nagios v1 attribute
sub NAGIOS_V2         { 1 << 4 }    # nagios v2 attribute
sub NAGIOS_V1_ONLY    { 1 << 5 }    # not valid for nagios v2
sub NAGIOS_V2_ONLY    { 1 << 6 }    # not valid for nagios v1
sub NAGIOS_NO_DISPLAY { 1 << 7 }    # should not be displayed by gui
sub NAGIOS_V3         { 1 << 8 }    # nagios v3 attribute
sub NAGIOS_V3_ONLY    { 1 << 9 }    # not valid for nagios v1 or v2
sub NAGIOS_GROUP_SYNC { 1 << 10 }   # keep sync'ed with members method in group object

# export constants - the :all tag will export them all
our %EXPORT_TAGS = (
    all => [
        qw(NAGIOS_NO_INHERIT NAGIOS_PERL_ONLY NAGIOS_V1 NAGIOS_V2 NAGIOS_V3 NAGIOS_V1_ONLY NAGIOS_V2_ONLY NAGIOS_V3_ONLY NAGIOS_NO_DISPLAY NAGIOS_GROUP_SYNC)
    ]
);
Exporter::export_ok_tags('all');

# we also export %nagios_setup only if it is asked for by name
push( @Nagios::Object::EXPORT_OK, '%nagios_setup' );

# all the data needed to set up all the objects
#   Object => {
#      attribute => [ Type, Flags ]
#   }
# Type: a type for validation _and_ for linking objects, so we know which
#       fields should point to an object rather than containing a scalar.
#       If the type is an array reference, it indicates that the entry
#       may have more than one value assigned.
# Flags: Really these are bitwise ORed flags, but recorded here as simple
#        integers for brevity.  The flags are defined as constants toward
#        the top of this file.
%nagios_setup = (
    Service => {
        use                 => [ 'Nagios::Service', 10 ],
        service_description => [ 'STRING',          10 ],
        display_name        => [ 'STRING',          280 ],
        host_name      => [ ['Nagios::Host'],         10 ],
        servicegroups  => [ ['Nagios::ServiceGroup'], 280 ],
        hostgroup_name => [ ['Nagios::HostGroup'],    256 ],
        is_volatile           => [ 'BINARY',          280 ],
        check_command         => [ 'Nagios::Command', 280 ],
        max_check_attempts    => [ 'INTEGER',         280 ],
        normal_check_interval => [ 'INTEGER',         280 ],
        retry_check_interval  => [ 'INTEGER',         280 ],
        check_interval        => [ 'INTEGER',         280 ],
        retry_interval        => [ 'INTEGER',         280 ],
        initial_state => [ [qw(o d u)], 280 ],
        active_checks_enabled  => [ 'BINARY',             280 ],
        passive_checks_enabled => [ 'BINARY',             280 ],
        check_period           => [ 'Nagios::TimePeriod', 280 ],
        parallelize_check      => [ 'BINARY',             280 ],
        obsess_over_service    => [ 'BINARY',             280 ],
        check_freshness        => [ 'BINARY',             280 ],
        freshness_threshold    => [ 'INTEGER',            280 ],
        event_handler          => [ 'Nagios::Command',    280 ],
        event_handler_enabled  => [ 'BINARY',             280 ],
        low_flap_threshold     => [ 'INTEGER',            280 ],
        high_flap_threshold    => [ 'INTEGER',            280 ],
        flap_detection_enabled => [ 'BINARY',             280 ],
        flap_detection_options => [ [qw(o d u)], 280 ],
        process_perf_data            => [ 'BINARY',             280 ],
        retain_status_information    => [ 'BINARY',             280 ],
        retain_nonstatus_information => [ 'BINARY',             280 ],
        notification_period          => [ 'Nagios::TimePeriod', 280 ],
        notification_interval        => [ 'INTEGER',            280 ],
        notification_options => [ [qw(u w c r)], 280 ],
        contacts       => [ ['Nagios::Contact'],      280 ],
        contact_groups => [ ['Nagios::ContactGroup'], 280 ],
        notifications_enabled => [ 'BINARY', 280 ],
        stalking_options => [ [qw(o w u c)], 280 ],
        failure_prediction_enabled => [ 'BINARY',              16 ],
        first_notification_delay   => [ 'INTEGER',             280 ],
        action_url                 => [ 'STRING',              280 ],
        notes                      => [ 'STRING',              280 ],
        notes_url                  => [ 'STRING',              280 ],
        name                       => [ 'service_description', 134 ],
        comment                    => [ 'comment',             280 ],
        file                       => [ 'filename',            280 ]
    },
    ServiceGroup => {
        use               => [ 'Nagios::ServiceGroup', 18 ],
        servicegroup_name => [ 'STRING',               18 ],
        alias             => [ 'STRING',               16 ],
        members => [ [ 'Nagios::Host', 'Nagios::Service' ], 16 ],
        servicegroup_members => [ ['Nagios::ServiceGroup'], 280 ],
        name    => [ 'servicegroup_name', 22 ],
        comment => [ 'comment',           22 ],
        file    => [ 'filename',          22 ]
    },
    Host => {
        use       => [ 'Nagios::Host', 10 ],
        host_name => [ 'STRING',       10 ],
        alias     => [ 'STRING',       280 ],
        address   => [ 'STRING',       280 ],
        parents    => [ ['Nagios::Host'],      280 ],
        hostgroups => [ ['Nagios::HostGroup'], 1304 ],
        check_command      => [ 'STRING',  280 ],
        max_check_attempts => [ 'INTEGER', 280 ],
        checks_enabled     => [ 'BINARY',  280 ],
        initial_state => [ [qw(o d u)], 280 ],
        active_checks_enabled  => [ 'BINARY',             280 ],
        passive_checks_enabled => [ 'BINARY',             280 ],
        check_freshness        => [ 'BINARY',             280 ],
        check_interval         => [ 'INTEGER',            280 ],
        retry_interval         => [ 'INTEGER',            768 ],
        obsess_over_host       => [ 'BINARY',             280 ],
        freshness_threshold    => [ 'INTEGER',            280 ],
        event_handler          => [ 'STRING',             280 ],
        event_handler_enabled  => [ 'BINARY',             280 ],
        check_period           => [ 'Nagios::TimePeriod', 280 ],
        low_flap_threshold     => [ 'INTEGER',            280 ],
        high_flap_threshold    => [ 'INTEGER',            280 ],
        flap_detection_enabled => [ 'BINARY',             280 ],
        flap_detection_options => [ [qw(o d u)], 280 ],
        process_perf_data            => [ 'BINARY', 280 ],
        retain_status_information    => [ 'BINARY', 280 ],
        retain_nonstatus_information => [ 'BINARY', 280 ],
        notification_period => [ 'Nagios::TimePeriod', 280 ],
        notification_interval => [ 'INTEGER', 280 ],
        notification_options => [ [qw(d u r)], 280 ],
        notifications_enabled => [ 'BINARY', 280 ],
        stalking_options => [ [qw(o d u)], 280 ],
        contacts       => [ ['Nagios::Contact'],      280 ],
        contact_groups => [ ['Nagios::ContactGroup'], 16 ],
        failure_prediction_enabled => [ 'BINARY',    16 ],
        first_notification_delay   => [ 'INTEGER',   280 ],
        action_url                 => [ 'STRING',    280 ],
        notes                      => [ 'STRING',    280 ],
        notes_url                  => [ 'STRING',    280 ],
        name                       => [ 'host_name', 280 ],
        comment                    => [ 'comment',   280 ],
        file                       => [ 'filename',  280 ]
    },
    HostGroup => {
        use            => [ 'Nagios::HostGroup', 280 ],
        hostgroup_name => [ 'STRING',            280 ],
        alias          => [ 'STRING',            280 ],
        contact_groups => [ ['Nagios::ContactGroup'], 40 ],
        members        => [ ['Nagios::Host'],         1304 ],
        hostgroup_members => [ ['Nagios::HostGroup'], 280 ],
        name    => [ 'hostgroup_name', 280 ],
        comment => [ 'comment',   280 ],
        file    => [ 'filename',  280 ]
    },
    Contact => {
        use                         => [ 'Nagios::Contact',    280 ],
        contact_name                => [ 'STRING',             280 ],
        alias                       => [ 'STRING',             280 ],
        host_notification_period    => [ 'Nagios::TimePeriod', 280 ],
        service_notification_period => [ 'Nagios::TimePeriod', 280 ],
        host_notification_options    => [ [qw(d u r n)],   280 ],
        service_notification_options => [ [qw(w u c r n)], 280 ],
        host_notification_commands    => [ ['Nagios::Command'], 280 ],
        service_notification_commands => [ ['Nagios::Command'], 280 ],
        email                         => [ 'STRING', 280 ],
        pager                         => [ 'STRING', 280 ],
        host_notifications_enabled    => [ 'BINARY', 280 ],
        service_notifications_enabled => [ 'BINARY', 280 ],
        can_submit_commands           => [ 'BINARY', 280 ],
        retain_status_information     => [ 'BINARY', 280 ],
        retain_nonstatus_information  => [ 'BINARY', 280 ],
        address1                      => [ 'STRING', 16 ],
        address2                      => [ 'STRING', 16 ],
        address3                      => [ 'STRING', 16 ],
        address4                      => [ 'STRING', 16 ],
        address5                      => [ 'STRING', 16 ],
        address6                      => [ 'STRING', 16 ],
        contactgroups => [ ['Nagios::ContactGroup'], 1040 ],
        name    => [ 'contact_name', 280 ],
        comment => [ 'comment',      280 ],
        file    => [ 'filename',     280 ]
    },
    ContactGroup => {
        use               => [ 'Nagios::ContactGroup', 280 ],
        contactgroup_name => [ 'STRING',               280 ],
        alias             => [ 'STRING',               280 ],
        members => [ ['Nagios::Contact'], 1304 ],
        contactgroup_members => [ ['Nagios::ContactGroup'], 280 ],
        name    => [ 'contactgroup_name', 280 ],
        comment => [ 'comment',           280 ],
        file    => [ 'filename',          280 ]
    },
    Command => {
        use          => [ 'Nagios::Command', 280 ],
        command_name => [ 'STRING',          280 ],
        command_line => [ 'STRING',          280 ],
        name         => [ 'command_name',    280 ],
        comment      => [ 'comment',         280 ],
        file         => [ 'filename',        280 ]
    },
    TimePeriod => {
        use             => [ 'Nagios::TimePeriod', 280 ],
        timeperiod_name => [ 'STRING',             280 ],
        alias           => [ 'STRING',             280 ],
        sunday          => [ 'TIMERANGE',          280 ],
        monday          => [ 'TIMERANGE',          280 ],
        tuesday         => [ 'TIMERANGE',          280 ],
        wednesday       => [ 'TIMERANGE',          280 ],
        thursday        => [ 'TIMERANGE',          280 ],
        friday          => [ 'TIMERANGE',          280 ],
        saturday        => [ 'TIMERANGE',          280 ],
        january         => [ 'TIMERANGE',          768 ],
        february        => [ 'TIMERANGE',          768 ],
        march           => [ 'TIMERANGE',          768 ],
        april           => [ 'TIMERANGE',          768 ],
        may             => [ 'TIMERANGE',          768 ],
        june            => [ 'TIMERANGE',          768 ],
        july            => [ 'TIMERANGE',          768 ],
        august          => [ 'TIMERANGE',          768 ],
        september       => [ 'TIMERANGE',          768 ],
        october         => [ 'TIMERANGE',          768 ],
        november        => [ 'TIMERANGE',          768 ],
        december        => [ 'TIMERANGE',          768 ],
        name            => [ 'timeperiod_name',    280 ],
        comment         => [ 'comment',            280 ],
        file            => [ 'filename',           280 ]
    },
    ServiceEscalation => {
        use       => [ 'Nagios::ServiceEscalation', 280 ],
        host_name => [ ['Nagios::Host'],            280 ],
        hostgroup_name => [ ['Nagios::HostGroup'], 280 ],
        service_description => [ 'Nagios::Service', 280 ],
        contacts       => [ ['Nagios::Contact'],      280 ],
        contact_groups => [ ['Nagios::ContactGroup'], 280 ],
        first_notification    => [ 'INTEGER',            280 ],
        last_notification     => [ 'INTEGER',            280 ],
        notification_interval => [ 'INTEGER',            280 ],
        escalation_period     => [ 'Nagios::TimePeriod', 16 ],
        escalation_options => [ [qw(w u c r)], 16 ],
        name    => [ 'generated', 280 ],
        comment => [ 'comment',   280 ],
        file    => [ 'filename',  280 ]
    },
    ServiceDependency => {
        use                           => [ 'Nagios::ServiceDependency', 280 ],
        dependent_host_name           => [ ['Nagios::Host'],            280 ],
        dependent_service_description => [ 'Nagios::Service',           280 ],
        hostgroup_name                => [ ['Nagios::HostGroup'],       280 ],
        dependent_hostgroup_name      => [ ['Nagios::HostGroup'],       280 ],
        host_name                     => [ ['Nagios::Host'],            280 ],
        service_description           => [ 'Nagios::Service',           280 ],
        inherits_parent               => [ 'INTEGER',                   280 ],
        execution_failure_criteria    => [ [qw(o w u c n)], 280 ],
        execution_failure_options     => [ [qw(o w u c n)], 280 ],
        notification_failure_criteria => [ [qw(o w u c n)], 280 ],
        notification_failure_options  => [ [qw(o w u c n)], 280 ],
        name    => [ 'generated', 280 ],
        comment => [ 'comment',   280 ],
        file    => [ 'filename',  280 ]
    },
    HostEscalation => {
        use       => [ 'Nagios::HostEscalation', 280 ],
        host_name => [ ['Nagios::Host'],         280 ],
        hostgroup => [ ['Nagios::HostGroup'],    280 ],
        contacts       => [ ['Nagios::Contact'],      280 ],
        contact_groups => [ ['Nagios::ContactGroup'], 280 ],
        first_notification    => [ 'INTEGER',   280 ],
        last_notification     => [ 'INTEGER',   280 ],
        notification_interval => [ 'INTEGER',   280 ],
        name                  => [ 'host_name', 280 ],
        comment               => [ 'comment',   280 ],
        escalation_options => [ [qw(d u r)], 280 ],
        file => [ 'filename', 280 ]
    },
    HostDependency => {
        use                      => [ 'Nagios::HostDependency', 280 ],
        dependent_host_name      => [ ['Nagios::Host'],         280 ],
        dependent_hostgroup_name => [ ['Nagios::HostGroup'],    280 ],
        host_name                => [ ['Nagios::Host'],         280 ],
        hostgroup_name           => [ ['Nagios::HostGroup'],    280 ],
        inherits_parent          => [ 'INTEGER',                16 ],
        notification_failure_criteria => [ [qw(o w u c n)], 280 ],
        notification_failure_options  => [ [qw(o w u c n)], 280 ],
        execution_failure_criteria    => [ [qw(o w u c n)], 16 ],
        execution_failure_options     => [ [qw(o w u c n)], 280 ],
        name    => [ 'generated', 280 ],
        comment => [ 'comment',   280 ],
        file    => [ 'filename',  280 ]
    },

    # Nagios 1.0 only
    HostGroupEscalation => {
        use       => [ 'Nagios::HostGroupEscalation', 40 ],
        hostgroup => [ 'Nagios::HostGroup',           40 ],
        contact_groups => [ ['Nagios::ContactGroup'], 40 ],
        first_notification    => [ 'INTEGER',   40 ],
        last_notification     => [ 'INTEGER',   40 ],
        notification_interval => [ 'INTEGER',   40 ],
        name                  => [ 'hostgroup', 44 ],
        comment               => [ 'comment',   44 ],
        file                  => [ 'filename',  44 ]
    },

    # Nagios 2.0 only
    HostExtInfo => {
        use       => [ 'HostExtInfo',  18 ],
        host_name => [ 'Nagios::Host', 18 ],
        hostgroup => [ ['Nagios::HostGroup'], 18 ],
        notes           => [ 'STRING',    16 ],
        notes_url       => [ 'STRING',    16 ],
        action_url      => [ 'STRING',    16 ],
        icon_image      => [ 'STRING',    16 ],
        icon_image_alt  => [ 'STRING',    16 ],
        vrml_image      => [ 'STRING',    16 ],
        statusmap_image => [ 'STRING',    16 ],
        '2d_coords'     => [ 'STRING',    16 ],
        '3d_coords'     => [ 'STRING',    16 ],
        name            => [ 'host_name', 20 ],
        comment         => [ 'comment',   20 ],
        file            => [ 'filename',  20 ]
    },

    # Nagios 2.0 only
    ServiceExtInfo => {
        use => [ 'ServiceExtInfo', 18 ],
        host_name => [ ['Nagios::Host'],      18 ],
        hostgroup => [ ['Nagios::HostGroup'], 18 ],
        service_description => [ 'Nagios::Service', 18 ],
        notes               => [ 'STRING',          16 ],
        notes_url           => [ 'STRING',          16 ],
        action_url          => [ 'STRING',          16 ],
        icon_image          => [ 'STRING',          16 ],
        icon_image_alt      => [ 'STRING',          16 ],
        name                => [ 'generated',       20 ],
        comment             => [ 'comment',         20 ],
        file                => [ 'filename',        20 ]
    }
);

# create a package for every key in %nagios_setup
foreach ( keys(%nagios_setup) ) {
    create_object_and_methods($_);
}

=head1 NAME

Nagios::Object - Creates perl objects to represent Nagios objects

=head1 DESCRIPTION

This module contains the code for creating perl objects to represent any of the Nagios objects.  All of the perl classes are auto-generated at compile-time, so it's pretty trivial to add new attributes or even entire objects.  The following is a list of currently supported classes:

 Nagios::TimePeriod
 Nagios::Command
 Nagios::Contact
 Nagios::ContactGroup
 Nagios::Host
 Nagios::Service
 Nagios::HostGroup
 Nagios::ServiceEscalation
 Nagios::HostDependency
 Nagios::HostEscalation
 Nagios::HostGroupEscalation
 Nagios::ServiceDependency
 -- next two are for status.dat in Nagios 2.x
 Nagios::Info
 Nagios::Program

=head1 EXAMPLE

 use Nagios::Object;
 my $generic_host = Nagios::Host->new(
    register                     => 0,
    parents                      => undef,
    check_command                => $some_command,
    max_check_attempts           => 3,
    checks_enabled               => 1,
    event_handler                => $some_command,
    event_handler_enabled        => 0,
    low_flap_threshold          => 0,
    high_flap_threshold         => 0,
    flap_detection_enabled       => 0,
    process_perf_data            => 1,
    retain_status_information    => 1,
    retain_nonstatus_information => 1,
    notification_interval        => $timeperiod,
    notification_options         => [qw(d u r)],
    notifications_enabled        => 1,
    stalking_options             => [qw(o d u)]
 );

 # this will automatically 'use' $generic_host
 my $localhost = $generic_host->new(
    host_name => "localhost",
    alias     => "Loopback",
    address   => "127.0.0.1"
 );

 my $hostname = $localhost->host_name();
 printf "max check attempts for $hostname is %s.\n",
     $localhost->max_check_attempts;
 
 $localhost->set_event_handler(
     Nagios::Command->new(
         command_name => "new_event_handler",
         command_line => "/bin/true"
     )
 );

=head1 METHODS

=over 4

=item new()

Create a new object of one of the types listed above.

Calling new() on an existing object will use the LHS object as the template for
the object being created.   This is mainly useful for creating objects without
involving Nagios::Object::Config (like in the test suite).

 Nagios::Host->new( ... );

=cut

# ---------------------------------------------------------------------------- #
sub new {
    my $parent = shift;
    my $type = ref($parent) ? ref($parent) : $parent;
    croak "single argument form of new() no longer supported"
        if ( @_ % 2 == 1 );
    my %args = @_;    # passed-in arguments hash

    if ( $type eq 'Nagios::Object' && $args{Type} ) {
        $type = delete $args{Type};
    }

    # for referencing %nagios_setup
    my $nagios_setup_key = ( split( /::/, $type ) )[1];

    #print "type: $type, key: $nagios_setup_key\n";

    confess
        "invalid type '$type' for Nagios::Object - does not exist in \%nagios_setup"
        if ( !exists $nagios_setup{$nagios_setup_key} );

    # set everything to undef by default
    my %default
        = map { $_ => undef } keys %{ $nagios_setup{$nagios_setup_key} };

    # if pre_link is set, don't set objects' resolved/registered flag
    if ($pre_link) {
        $default{_has_been_resolved}   = undef;
        $default{_has_been_registered} = undef;
    }

    # _validate will be called by _set, which will croak if this is wrong
    else {
        $default{_has_been_resolved}   = 1;
        $default{_has_been_registered} = 1;
    }

    # instantiate an object
    my $self = bless( \%default, $type );
    $self->{_nagios_setup_key} = $nagios_setup_key;

    # fill in the object with it's data from %args
    # if $pre_link is set, it is expected it will mostly be filled in
    # after instantiation, so probably not much will happen here
    foreach my $key ( keys %default ) {
        if ( exists( $args{$key} ) && defined( $args{$key} ) ) {

            # timeranges must be parsed into ARRAYs, so parse it here so that
            # users don't have to figure out the arrays and so we don't have
            # to export parse_time_range
            if ( $nagios_setup{$nagios_setup_key}->{$key}[0] eq 'TIMERANGE' )
            {
                $args{$key} = parse_time_range( $args{$key} );
            }
            $default{$key} = $args{$key};
        }
    }

    # this lets Nagios::Object sanely build heirarchies without Object::Config
    # by letting the caller say $parent->new() rather than, e.g.
    # Nagios::TimePeriod->new( use => 'parent name' )
    if ( ref($parent) ) {
        $self->{_use} = $parent;
        $self->{use}  = $parent->name;
    }

    return $self;
}

sub setup_key { $_[0]->{_nagios_setup_key} }

# ---------------------------------------------------------------------------- #
# parse the time range text
sub parse_time_range ($) {
    my $text = shift;
    return $text if ( !defined($text) || ref($text) );
    $text =~ s/\s+//g;
    return undef if ( !$text );

    my @retval = ();

    # convert time to seconds since midnight
    sub t2s {
        my $t = shift;
        my ( $h, $m, $s ) = split /:/, $t, 3;
        $s = 0 if ( !$s );
        $s += $h * 3600;
        $s += $m * 60;
        return $s;
    }

    foreach my $range ( split /,/, $text ) {
        my ( $start, $end ) = split /-/, $range;
        push( @retval, [ t2s($start), t2s($end) ] );
    }

    return wantarray ? @retval : \@retval;
}

# ---------------------------------------------------------------------------- #
# opposite of parse_time_range
sub dump_time_range ($) {
    my $range = shift;
    return undef  if ( !$range );
    return $range if ( !ref($range) );

    # convert seconds from midnight to Nagios time format
    sub s2t {
        my $s   = shift;
        my $hr  = sprintf "%02d", int( $s / 3600 );
        my $min = $s % 3600;
        my $sec = $min % 60;
        $min = sprintf "%02d", int( $min / 60 );
        return $sec == 0 ? "$hr:$min" : "$hr:$min:$sec";
    }

    my @retval = ();
    foreach (@$range) {
        push( @retval, s2t( $_->[0] ) . '-' . s2t( $_->[1] ) );
    }
    return join ',', @retval;
}

=item dump()

Output a Nagios define { } block from an object.  This is still EXPERIMENTAL,
but may eventually be robust enough to use for a configuration GUI.   Passing
in a single true argument will tell it to flatten the object inheritance on dump.

 print $object->dump();
 print $object->dump(1); # flatten

=cut

# ---------------------------------------------------------------------------- #
sub dump {
    my ( $self, $flatten ) = @_;
    my $retval = 'define ';

    $retval .= lc( ( split /::/, ref($self) )[1] ) . " {\n";

    foreach my $attribute ( $self->list_valid_attributes ) {
        my $value = $self->$attribute();
        next if ( $attribute eq 'register' && !defined $value );

        my $attrtype = $self->attribute_type($attribute);

        if ( blessed $value && UNIVERSAL::can( $value, 'name' ) ) {

            # maybe add an additional check against %nagios_setup
            $value = $value->name;
        }
        elsif ( $attrtype eq 'TIMERANGE' ) {
            $value = dump_time_range($value);
        }
        elsif ( ref($value) eq 'ARRAY' ) {
            $value = join ',', map { blessed $_ ? $_->name : $_ } @$value;
        }

        if ( exists $self->{$attribute} && defined $self->{$attribute} ) {
            $retval .= "\t$attribute $value\n";
        }
        elsif ($flatten) {
            $retval .= "\t$attribute " . $value . "\n";
        }
    }

    $retval .= "}\n";
}

sub template {
    my $self = shift;

    if ( exists $self->{_use} && blessed $self->{_use} ) {
        return $self->{_use};
    }

    # when objects are built by Nagios::Object::Config, it's necessary
    # to run another step after parsing to link up all of the objects
    # this method does it on-demand
    elsif ( $self->{use} ) {
        if ( my $parser = $self->{object_config_object} ) {
            $parser->resolve($self);
            return $self->{_use};
        }
        else {
            confess
                "Unable to walk object heirarchy without object configuration.";
        }
    }
}

=item name()

This method is common to all classes created by this module.  It should always return the textual name for an object.  It is used internally by the Nagios::Object modules to allow polymorphism (which is what makes this module so compact).  This is the only way to retrieve the name of a template, since they are identified by their "name" field.

 my $svc_desc = $service->name;
 my $hostname = $host->name;

Which is just short for:

 my $svc_desc = $service->service_description;
 my $hostname = $service->host_name;

=cut

# ---------------------------------------------------------------------------- #
my $_name_hack;

sub name {
    my $self = shift;

    if ( !$self->register ) {
        return $self->{name};
    }
    else {
        my $name_method = $self->_name_attribute;
        if ( $name_method eq 'generated' ) {
            $_name_hack++;
            return
                ref($self) . '-'
                . $_name_hack;    # FIXME: this should work but feels wrong
        }

        my $name = $self->$name_method();

        # recurse down on references to get the names, then generate something
        # more sensible
        if ( ref($name) && UNIVERSAL::can( $name, 'name' ) ) {
            $name = lc( ref($self) ) . '-' . $name->name;
            $name =~ s/^nagios:://;
            $name =~ s/::/_/g;
        }
        return $name;
    }
}

# ---------------------------------------------------------------------------- #
# not autogenerated, but needs to exist
sub set_name {
    my ( $self, $val ) = @_;
    confess "cannot set name of objects with multi-key identity"
        if ( ref $self->{name} eq 'ARRAY' );
    $self->{name} = $val;
}

=item register()

Returns true/undef to indicate whether the calling object is registerable or not.

 if ( $object->register ) { print $object->name, " is registerable." }

=cut

# ---------------------------------------------------------------------------- #
sub register {
    my $self = shift;
    return undef if ( defined $self->{register} && $self->{register} == 0 );
    return 1;
}

# not autogenerated, but needs to exist
sub set_register {
    my ( $self, $value ) = @_;
    $self->{register} = $value;
}

# ---------------------------------------------------------------------------- #

=item has_attribute()

Returns true/undef to indicate whether the calling object has the attribute specified as the only argument.

 # check to see if $object has attribute "command_line"
 die if ( !$object->has_attribute("command_line") );

=cut

sub has_attribute { exists $nagios_setup{ $_[0]->setup_key }->{ $_[1] } }

=item list_attributes()

Returns a list of valid attributes for the calling object.

 my @host_attributes = $host->list_attributes();

=cut

sub list_attributes { keys( %{ $nagios_setup{ $_[0]->setup_key } } ) }

sub list_valid_attributes {
    my $self    = shift;
    my $package = $nagios_setup{ $self->setup_key };

    my @valid;
    foreach my $key ( keys %$package ) {
        if ( ( $package->{$key}[1] & NAGIOS_PERL_ONLY ) == 0 ) {
            push @valid, $key;
        }
    }

    return sort @valid;
}

=item attribute_type()

Returns the type of data expected by the object's set_ method for the given attribute.  For some fields like notification_options, it may return "char_flag."

For "name" attributes, it will simply return whatever %setup_data contains.

This method needs some TLC ...

 my $type = $host->attribute_type("notification_period");

=cut

sub attribute_type {
    my $self = $_[0];

    #                             self               field type
    my $type = $nagios_setup{ $_[0]->setup_key }->{ $_[1] }[0];
    if ( ref($type) eq 'ARRAY' ) {
        if ( @$type == 1 ) {
            return $type->[0];
        }
        elsif ( @$type > 1 && length( $type->[0] ) == 1 ) {
            return "char_flag";
        }

        #elsif ( $_[1] eq 'name' || @$type > 1 ) {
        else {
            return $type;
        }
    }
    else {
        return $type;
    }
}

=item attribute_is_list()

Returns true if the attribute is supposed to be a list (ARRAYREF).

 if ( $object->attribute_is_list("members") ) {
    $object->set_members( [$member] );
 } else {
    $object->set_members( $member );
 }

=cut

sub attribute_is_list {
    my $type = ref( $_[0] ) ? ref( $_[0] ) : $_[0];
    return 1
        if ( ref $nagios_setup{ $_[0]->setup_key }->{ $_[1] }[0] eq 'ARRAY' );
    undef;
}

# ---------------------------------------------------------------------------- #
# mostly these are only for use by other Nagios::Modules
sub resolved {
    if ( $_[1] ) { $_[0]->{_has_been_resolved} = $_[1] }
    return $_[0]->{_has_been_resolved};
}

sub registered {
    if ( $_[1] ) { $_[0]->{_has_been_registered} = $_[1] }
    return $_[0]->{_has_been_registered};
}

sub validate_object_type {
    my $type = lc( ref( $_[1] ) ? ref( $_[1] ) : $_[1] );
    $type =~ s/^nagios:://;
    my ($result) = grep {/^$type$/i} keys %nagios_setup;
    return defined $result ? "Nagios::$result" : undef;
}

sub list_valid_fields {
    my $type = ref( $_[0] ) ? ref(shift) : shift;
    $type =~ s/^Nagios:://;
    foreach my $key ( keys %nagios_setup ) {
        if ( lc $key eq lc $type ) {
            return keys %{ $nagios_setup{$key} };
        }
    }
    return undef;
}

# ---------------------------------------------------------------------------- #
# a validating set routine used by all of the autogenerated methods
sub _set ($ $ $) {
    my ( $self, $key, $value ) = @_;
    croak "$key does not exist for this object ... template?"
        if ( !exists( $self->{$key} ) );

    my $vf = $nagios_setup{ $self->setup_key };

    if ( !$pre_link && !$fast_mode && exists $vf->{$key} ) {

       # validate passed in arugments against arrayref in $vf (\%valid_fields)
        $self->_validate( $key, $value, @{ $vf->{$key} } );
    }

    # Nagios allows the usage of a '+' sign. This breaks member lists.
    # Ignore the '+' sign completely for now.
    if ( ref $vf->{$key}[0] eq 'ARRAY' && $value =~/^\+(.+)$/ ) {
        $value = $1;
    }

    if ( ref $vf->{$key}[0] eq 'ARRAY' && $value =~ /,/ ) {
        $value = [ split /\s*,\s*/, $value ];
    }

    # set the value (which is an anonymous subroutine)
    if ( defined($value) ) {
        $self->{$key} = $value;
    }
    else {
        $self->{$key} = undef;
    }
}

# ---------------------------------------------------------------------------- #
# verfiy that the type of an object is what it is supposed to be as specified
# in the hash in BEGIN
sub _validate {
    my ( $self, $key, $value, $type, $flags ) = @_;

    croak "$key is required but is ($value) undefined"
        if ( !defined $value
        && ( $flags & NAGIOS_NO_INHERIT ) == NAGIOS_NO_INHERIT );

    return $value if ( !defined $value );

    # types in an arrayref indicate that the value may be a list as well
    # lists may only be of single characters or objects for now
    if ( ref $type eq 'ARRAY' ) {

        # only 1 entry in $type list, so it's probably a class
        if ( @$type == 1 && $type->[0] =~ /^Nagios::.*$/ ) {

            # process single values as an arrayref anyways for consistency
            if ( ref($value) ne 'ARRAY' ) { $value = [$value] }
            foreach my $val (@$value) {
                croak "object isa '"
                    . ref($val)
                    . "' when it should be a '$type'"
                    if ( ref($val) ne $type->[0] );
            }
        }

        # all other list entries must be single character type - a,s,d,f style
        else {

            # map valid entries onto a hash for easy comparison
            my %possible = map { $_ => 1 } @$type;

            # autosplit
            if ( ref($value) ne 'ARRAY' ) {
                $value = [ split /,/, $value ];
            }
            foreach my $v (@$value) {
                croak "\"$v\" is an invalid entry for $key"
                    unless ( exists $possible{$v} );
            }
        }
    }
    elsif ( $type =~ /^Nagios::.*$/ ) {
        croak "object isa '" . ref($value) . "' when it should be a '$type'"
            if ( ref($value) ne $type );
    }
    elsif ( ref($value) eq 'ARRAY' && $type ne 'TIMERANGE' ) {
        croak "$key cannot have multiple " . ref($value) . " values.";
    }
    elsif ( $type eq 'BINARY' ) {
        confess "argument to set_$key must NOT be a reference"
            if ( ref($value) );
        croak "$key must be 1 or 0" if ( $value != 0 && $value != 1 );
    }
    elsif ( $type eq 'STRING' || $type eq 'INTEGER' ) {
        confess "argument to set_$key must NOT be a reference"
            if ( ref($value) );
        croak "$key must have a length greater than 0"
            if ( length($value) < 1 );
        croak "$key must be an INTEGER"
            if ( $type eq 'INTEGER' && $value =~ /[^\d]/ );
    }
    elsif ( $type eq 'TIMERANGE' ) {
        croak "TIMERANGE must be an ARRAY refrerence"
            if ( ref($value) ne 'ARRAY' );
        foreach my $rng (@$value) {
            croak "elements of TIMERANGE must be ARRAY refrerences"
                if ( ref($rng) ne 'ARRAY' );
            croak "start/end times in ranges must be an integer of seconds"
                if ( $rng->[0] =~ /[^\d]/ || $rng->[1] =~ /[^\d]/ );
        }
    }
    else {
        confess "invalid call to _validate";
    }

    return $value;
}

# support "hostgroup" alongside "hostgroups" by piggybacking it
sub hostgroup_name {
    my $self = shift;

    # Since this method is available in all objects, perform a check in
    # the config to see if its actually valid on the object
    (my $type = ref $self) =~ s/.*:://;
    if(!$nagios_setup{$type}{hostgroup_name}) {
        return;
    }
    if ( $self->can('hostgroup') ) {
        return $self->hostgroup(@_);
    }
    else {
        confess "Called hostgroup() on an object that doesn't support it.";
    }
}

sub set_hostgroup_name {
    my $self = shift;
    if ( $self->can('hostgroup') ) {
        my @existing = $self->hostgroup;
        return $self->set_hostgroup( [ @existing, shift ] );
    }
    else {
        confess
            "Called set_hostgroup() on an object that doesn't support it.";
    }
}

# support shorthand "host" for "host_name" ... this is really annoying and
# can probably also be automated, but for now it just needs to be fixed
sub host {
    my $self = shift;
    if ( $self->can('host_name') ) {
        return $self->host_name(@_);
    }
    else {
        confess "Called host() on an object that doesn't support it.";
    }
}

sub set_host {
    my $self = shift;
    if ( $self->can('set_host_name') ) {
        return $self->set_host_name(@_);
    }
    else {
        confess "Called set_host() on an object that doesn't support it.";
    }
}

# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #

# use %nagios_setup to create all of the known methods at compile time
GENESIS: {
    no warnings;

    # this function can be called externally to create another object
    # type inside Nagios::Object with all the same capabilities as
    # those created at BEGIN - a hash like the one above will have
    # to be created and have the exact same name.  It'll also have to
    # be a global within the namespace
    sub create_object_and_methods {
        my $object = shift;

        # create a package name
        my $pkg = 'Nagios::' . $object;

        # fill in @ISA for each class
        my $isa = do { \@{ $pkg . '::ISA' } };
        push( @$isa, 'Nagios::Object' );

        # save off this list of naming (think primary key) attributes
        # access them via method $obj->_name_attribute
        my $name_attr_list = $nagios_setup{$object}->{name}[0];
        *{"$pkg\::_name_attribute"} = sub {$name_attr_list};

        # create methods for each entry in $nagios_setup{$object}
        foreach my $method ( keys( %{ $nagios_setup{$object} } ) ) {

            # name() is a special case and is implemented by hand
            next if ( $method eq 'name' );

        # the members() method in ServiceGroup is implemented manually (below)
            next
                if ( $pkg eq 'Nagios::ServiceGroup' && $method eq 'members' );

            $pkg->_make_method($method);
        }

        *{"$pkg\::AUTOLOAD"} = \&Nagios::Object::AUTOLOAD;
        *{"$pkg\::DESTROY"} = sub { };
    }

    # create methods on-the-fly
    sub _make_method {
        my ( $pkg, $method ) = @_;

        # create set_ method
        *{"$pkg\::set_$method"} = sub { shift->_set( $method, @_ ); };

        # create get method
        *{"$pkg\::$method"} = sub {
            my $self  = shift;
            my $value = $self->{$method};

            if ( defined $value || $method eq 'use' ) {
                return $value;
            }
            else {
                my $template = $self->template;
                if ( $template && $template->can($method) ) {
                    return $template->$method;
                }
            }
            return undef;
        };    # end of anonymous "get" subroutine
    }
}

sub DESTROY { }

sub AUTOLOAD {
    our $AUTOLOAD;

    # this will break if there are ever more than 3 parts to a package name
    my ( $top, $setup_key, $method ) = split /::/, $AUTOLOAD;
    my $pkg = $top . '::' . $setup_key;

    my $setup_field = $method;
    if ( $method =~ /^set_(.*)$/ ) {
        $setup_field = $1;
    }

    if ( exists $nagios_setup{$setup_key}->{$setup_field} ) {
        $pkg->_make_method($setup_field);
    }
    else {
        confess
            "Invalid method call.   $pkg does not know about method $method.";
    }

    goto \&{$AUTOLOAD};
}

# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# special-case methods coded straight into their packages

1;

package Nagios::Host;
our $VERSION = $Nagios::Object::VERSION;

# aliases
sub hostgroups     { shift->hostgroup(@_); }
sub set_hostgroups { shift->set_hostgroup(@_); }

1;

package Nagios::HostGroup;
our $VERSION = $Nagios::Object::VERSION;

# aliases
sub hostgroup     { shift->hostgroup_name(@_); }
sub set_hostgroup { shift->set_hostgroup_name(@_); }

1;

package Nagios::ServiceGroup;
use Carp;
our $VERSION = $Nagios::Object::VERSION;

sub members {
    my $self = shift;
    if ( $self->{members} ) {
        my @copy = @{ $self->{members} };
        return \@copy;
    }
    else {
        return [];
    }
}

sub set_members {
    my $self = shift;
    my ( @objects, @members );

    # @members will be an arrayref of [ host_name => service_description ]
    # or Service objects, depending on whether Nagios::Object::Config
    # has resolved yet
    if ( $self->resolved ) {
        foreach my $item (@_) {
            confess
                "set_members() arguments must be objects after resolve_objects() has been called."
                unless ( ref($item) );
            push @members, $item;
        }
    }

    # also, before resolution, append to the list rather than replace it
    else {
        @members = @{ $self->{members} } if $self->{members};
        foreach my $item (@_) {
            if ( ref($item) eq 'ARRAY' && @$item == 2 ) {
                push @members, $item;
            }
            elsif ( defined($item) && length($item) ) {
                push @members, $self->_split_members($item);
            }
            else {
                confess "Don't know what to do with a $item!";
            }
        }
    }

    $self->{members} = \@members;
}

sub _split_members {
    my ( $self, $string ) = @_;
    my @out;
    my @pieces = split /\s*,\s*/, $string;
    for ( my $i = 0; $i < @pieces; $i += 2 ) {
        push @out, [ $pieces[$i] => $pieces[ $i + 1 ] ];
    }

    #warn Data::Dumper::Dumper(\@out);
    return @out;
}

1;

package Nagios::Service;
our $VERSION = $Nagios::Object::VERSION;

1;

__END__

=back

=head1 AUTHOR

Al Tobey <tobeya@cpan.org>

Thank you to the fine people of #perl on freenode.net for helping me
with some hairy code and silly optimizations.

=head1 WARNINGS

See AUTHOR.

=cut

