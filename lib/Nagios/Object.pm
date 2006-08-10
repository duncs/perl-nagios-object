###########################################################################
#                                                                         #
# Nagios::Object                                                          #
# Written by Albert Tobey <tobeya@cpan.org>                               #
# Copyright 2003, Albert P Tobey                                          #
# CVS Revision $Revision: 1.12 $                                           #
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
@Nagios::Object::ISA = qw( Exporter );
$Nagios::Object::VERSION = 0.06;

our $pre_link = undef;
our $fast_mode = undef;
our %nagios_setup;

# constants for flags in %nagios_setup
sub NAGIOS_NO_INHERIT { 1<<1 } # cannot inherit from template
sub NAGIOS_PERL_ONLY  { 1<<2 } # perl module only attribute
sub NAGIOS_V1         { 1<<3 } # nagios v1 attribute
sub NAGIOS_V2         { 1<<4 } # nagios v2 attribute
sub NAGIOS_V1_ONLY    { 1<<5 } # not valid for nagios v2
sub NAGIOS_V2_ONLY    { 1<<6 } # not valid for nagios v1
sub NAGIOS_NO_DISPLAY { 1<<7 } # should not be displayed by gui

# export constants - the :all tag will export them all
our %EXPORT_TAGS = (all => [qw(NAGIOS_NO_INHERIT NAGIOS_PERL_ONLY NAGIOS_V1 NAGIOS_V2 NAGIOS_V1_ONLY NAGIOS_V2_ONLY NAGIOS_NO_DISPLAY)] );
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
        use                           => ['Nagios::Service',         10 ],
        service_description           => ['STRING',                  10 ],
        host_name                     => [['Nagios::Host'],          10 ],
        hostgroup_name                => [['Nagios::HostGroup'],     10 ],
        servicegroup_name             => [['Nagios::ServiceGroup'],  16 ],
        hostgroups                    => [['Nagios::HostGroup'],     18 ],
        servicegroups                 => [['Nagios::ServiceGroup'],  18 ],
        is_volatile                   => ['BINARY',                  8  ],
        check_command                 => ['Nagios::Command',         8  ],
        max_check_attempts            => ['INTEGER',                 8  ],
        normal_check_interval         => ['INTEGER',                 8  ],
        retry_check_interval          => ['INTEGER',                 8  ],
        active_checks_enabled         => ['BINARY',                  8  ],
        passive_checks_enabled        => ['BINARY',                  8  ],
        check_period                  => ['Nagios::TimePeriod',      8  ],
        parallelize_check             => ['BINARY',                  8  ],
        obsess_over_service           => ['BINARY',                  8  ],
        check_freshness               => ['BINARY',                  8  ],
        freshness_threshold           => ['INTEGER',                 8  ],
        event_handler                 => ['Nagios::Command',         8  ],
        event_handler_enabled         => ['BINARY',                  8  ],
        low_flap_threshold            => ['INTEGER',                 8  ],
        high_flap_threshold           => ['INTEGER',                 8  ],
        flap_detection_enabled        => ['BINARY',                  8  ],
        process_perf_data             => ['BINARY',                  8  ],
        retain_status_information     => ['BINARY',                  8  ],
        retain_nonstatus_information  => ['BINARY',                  8  ],
        notification_period           => ['Nagios::TimePeriod',      8  ],
        notification_interval         => ['INTEGER',                 8  ],
        notification_options          => [[qw(u w c r)],             8  ],
        contact_groups                => [['Nagios::ContactGroup'],  8  ],
        notifications_enabled         => ['BINARY',                  8  ],
        stalking_options              => [[qw(o w u c)],             8  ],
        failure_prediction_enabled    => ['BINARY',                  16 ],
        name                          => ['service_description',     134],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    ServiceGroup => {
        use                           => ['Nagios::ServiceGroup',    18 ],
        servicegroup_name             => ['STRING',                  18 ],
        alias                         => ['STRING',                  16 ],
        members                       => [['Nagios::Host',
                                           'Nagios::Service'],       16 ],
        name                          => ['servicegroup_name',       22 ],
        comment                       => ['comment',                 22 ],
        file                          => ['filename',                22 ]
    },
    Host => {
        use                           => ['Nagios::Host',            10 ],
        host_name                     => ['STRING',                  10 ],
	    alias                         => ['STRING',                  8  ],
	    address                       => ['STRING',                  8  ],
	    parents                       => [['Nagios::Host'],          8  ],
        hostgroups                    => [['Nagios::HostGroup'],     18 ],
	    check_command                 => ['STRING',                  8  ],
	    max_check_attempts            => ['INTEGER',                 8  ],
	    checks_enabled                => ['BINARY',                  8  ],
	    event_handler                 => ['STRING',                  8  ],
	    event_handler_enabled         => ['BINARY',                  8  ],
	    low_flap_threshold            => ['INTEGER',                 8  ],
	    high_flap_threshold           => ['INTEGER',                 8  ],
	    flap_detection_enabled        => ['BINARY',                  8  ],
	    process_perf_data             => ['BINARY',                  8  ],
	    retain_status_information     => ['BINARY',                  8  ],
	    retain_nonstatus_information  => ['BINARY',                  8  ],
	    notification_period           => [['Nagios::TimePeriod'],    8  ],
	    notification_interval         => ['INTEGER',                 8  ],
	    notification_options          => [[qw(d u r)],               8  ],
	    notifications_enabled         => ['BINARY',                  8  ],
	    stalking_options              => [[qw(o d u)],               8  ],
	    contact_groups                => [['Nagios::ContactGroup'],  16 ],
        failure_prediction_enabled    => ['BINARY',                  16 ],
	    name                          => ['host_name',               6  ],
	    comment                       => ['comment',                 6  ],
	    file                          => ['filename',                6  ]
    },
    HostGroup => {
	    use                           => ['Nagios::HostGroup',       8  ],
        hostgroup_name                => ['STRING',                  8  ],
        alias                         => ['STRING',                  8  ],
        contact_groups                => [['Nagios::ContactGroup'],  40 ],
        members	                      => [['Nagios::Host'],          8  ],
        name                          => ['hostgroup_name',          6  ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    Contact => {
        use                           => ['Nagios::Contact',         8  ],
        contact_name                  => ['STRING',                  8  ],
        alias                         => ['STRING',                  8  ],
        host_notification_period      => ['Nagios::TimePeriod',      8  ],
		service_notification_period   => ['Nagios::TimePeriod',      8  ],
        host_notification_options     => [[qw(d u r n)],             8  ],
		service_notification_options  => [[qw(w u c r n)],           8  ],
		host_notification_commands    => [['Nagios::Command'],       8  ],
		service_notification_commands => [['Nagios::Command'],       8  ],
		email                         => ['STRING',                  8  ],
		pager                         => ['STRING',                  8  ],
        address1                      => ['STRING',                  16 ],
        address2                      => ['STRING',                  16 ],
        address3                      => ['STRING',                  16 ],
        address4                      => ['STRING',                  16 ],
        address5                      => ['STRING',                  16 ],
        address6                      => ['STRING',                  16 ],
        contactgroups                 => [['Nagios::ContactGroup'],  16 ],
        name                          => ['contact_name',            6  ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    ContactGroup => {
	    use                           => ['Nagios::ContactGroup',    8  ],
        contactgroup_name             => ['STRING',                  8  ],
        alias                         => ['STRING',                  8  ],
        members	                      => [['Nagios::Contact'],       8  ],
        name                          => ['contactgroup_name',          ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    Command => {
	    use                           => ['Nagios::Command',         8  ],
        command_name                  => ['STRING',                  8  ],
        command_line                  => ['STRING',                  8  ],
        name                          => ['command_name',               ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    TimePeriod => {
        use                           => ['Nagios::TimePeriod',      8  ],
		timeperiod_name               => ['STRING',                  8  ],
        alias                         => ['STRING',                  8  ],
        sunday                        => ['TIMERANGE',               8  ],
        monday                        => ['TIMERANGE',               8  ],
        tuesday                       => ['TIMERANGE',               8  ],
        wednesday                     => ['TIMERANGE',               8  ],
        thursday                      => ['TIMERANGE',               8  ],
        friday                        => ['TIMERANGE',               8  ],
        saturday                      => ['TIMERANGE',               8  ],
        name                          => ['timeperiod_name',         6  ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    }, 
    ServiceEscalation => {
	    use                           => ['Nagios::ServiceEscalation',8 ],
		host_name                     => ['Nagios::Host',            8  ],
        hostgroup_name                => ['Nagios::HostGroup',       8  ],
		service_description           => ['Nagios::Service',         8  ],
        contact_groups                => [['Nagios::ContactGroup'],  8  ],
        first_notification            => ['INTEGER',                 8  ],
        last_notification             => ['INTEGER',                 8  ],
        notification_interval         => ['INTEGER',                 8  ],
        name                          => [['host_name',
                                           'service_description'],   6  ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    ServiceDependency => {
	    use                           => ['Nagios::ServiceDependency',8 ],
        dependent_host_name           => ['Nagios::Host',            8  ],
        dependent_service_description => ['Nagios::Service',         8  ],
		host_name                     => ['Nagios::Host',            8  ],
		service_description           => ['Nagios::Service',         8  ],
		execution_failure_criteria    => [[qw(o w u c n)],           8  ],
		notification_failure_criteria => [[qw(o w u c n)],           8  ],
        name                          => [[qw(dependent_host_name
                                              dependent_service_description
                                              host_name
                                              service_description)], 6  ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    HostEscalation => {
	    use                           => ['Nagios::HostEscalation',  8  ],
		host_name                     => ['Nagios::Host',            8  ],
		hostgroup_name                => ['Nagios::HostGroup',       16 ],
        contact_groups                => [['Nagios::ContactGroup'],  8  ],
        first_notification            => ['INTEGER',                 8  ],
        last_notification             => ['INTEGER',                 8  ],
        notification_interval         => ['INTEGER',                 8  ],
        name                          => ['host_name',               6  ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    HostDependency => {
	    use                           => ['Nagios::HostDependency',  8  ],
        dependent_host_name           => ['Nagios::Host',            8  ],
		host_name                     => ['Nagios::Host',            8  ],
        inherits_parent               => ['INTEGER',                 16 ],
		notification_failure_criteria => [[qw(o w u c n)],           8  ],
		execution_failure_criteria    => [[qw(o w u c n)],           16 ],
        name                          => [['host_name',
                                           'dependent_host_name'],   6  ],
        comment                       => ['comment',                 6  ],
        file                          => ['filename',                6  ]
    },
    # Nagios 1.0 only
    HostGroupEscalation => {
	    use                           => ['Nagios::HostGroupEscalation', 40 ],
		hostgroup_name                => ['Nagios::HostGroup',       40 ],
        contact_groups                => [['Nagios::ContactGroup'],  40 ],
        first_notification            => ['INTEGER',                 40 ],
        last_notification             => ['INTEGER',                 40 ],
        notification_interval         => ['INTEGER',                 40 ],
        name                          => ['hostgroup_name',          44 ],
        comment                       => ['comment',                 44 ],
        file                          => ['filename',                44 ]
    },
    # Nagios 2.0 only
    HostExtInfo => {
        use                           => ['HostExtInfo',             18 ],
        host_name                     => ['Nagios::Host',            18 ],
        hostgroup_name                => [['Nagios::HostGroup'],     18 ],
        notes                         => ['STRING',                  16 ],
        notes_url                     => ['STRING',                  16 ],
        icon_image                    => ['STRING',                  16 ],
        icon_image_alt                => ['STRING',                  16 ],
        vrml_image                    => ['STRING',                  16 ],
        statusmap_image               => ['STRING',                  16 ],
        '2d_coords'                   => ['STRING',                  16 ],
        '3d_coords'                   => ['STRING',                  16 ],
        name                          => ['host_name',               20 ],
        comment                       => ['comment',                 20 ],
        file                          => ['filename',                20 ]
    },
    # Nagios 2.0 only
    ServiceExtInfo => {
        use                           => ['ServiceExtInfo',          18 ],
        host_name                     => ['Nagios::Host',            18 ],
        service_description           => ['Nagios::Service',         18 ],
        notes                         => ['STRING',                  16 ],
        notes_url                     => ['STRING',                  16 ],
        icon_image                    => ['STRING',                  16 ],
        icon_image_alt                => ['STRING',                  16 ],
        name                          => [['host_name',
                                           'service_description'],   20 ],
        comment                       => ['comment',                 20 ],
        file                          => ['filename',                20 ]
    }
);


# create a package for every key in %nagios_setup
foreach ( keys(%nagios_setup) ) {
    create_object_and_methods( $_ );
}

=head1 NAME

Nagios::Object

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

 my $localhost = Nagios::Host->new(
    use       => $generic_host,
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
 Nagios::Host->new( ... );

=cut

# ---------------------------------------------------------------------------- #
sub new {
    my $type = ref($_[0]) ? ref(shift) : shift;
    croak "single argument form of new() no longer supported" if ( @_ % 2 == 1 );
    my %args = @_; # passed-in arguments hash
    
    if ( $type eq 'Nagios::Object' && $args{Type} ) {
        $type = delete $args{Type};
    }

    # for referencing %nagios_setup
    my $nagios_setup_key = (split( /::/, $type))[1];
    #print "type: $type, key: $nagios_setup_key\n";

    confess "invalid type '$type' for Nagios::Object - does not exist in \%nagios_setup"
        if ( !exists $nagios_setup{$nagios_setup_key} );
        
    # set everything to undef by default
    my %default = map { $_ => undef } keys %{$nagios_setup{$nagios_setup_key}};

    # if pre_link is set, don't set objects' resolved/registered flag
    if ( $pre_link ) {
        $default{_has_been_resolved} = undef;
        $default{_has_been_registered} = undef;
    }
    # _validate will be called by _set, which will croak if this is wrong
    else {
        $default{_has_been_resolved} = 1;
        $default{_has_been_registered} = 1;
    }

    # instantiate an object
    my $self = bless( \%default, $type );
    $self->{_nagios_setup_key} = $nagios_setup_key;

    # fill in the object with it's data from %args
    # if $pre_link is set, it is expected it will mostly be filled in
    # after instantiation, so probably not much will happen here
    foreach my $key ( keys %default ) {
        if ( exists($args{$key}) && defined($args{$key}) ) {
            # timeranges must be parsed into ARRAYs, so parse it here so that
            # users don't have to figure out the arrays and so we don't have
            # to export parse_time_range
            if ( $nagios_setup{$nagios_setup_key}->{$key}[0] eq 'TIMERANGE' ) {
                $args{$key} = parse_time_range( $args{$key} );
            }
            # now, use the _set instead of directly setting for consistency
            $self->_set( $key, $args{$key} );
        }
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
        my( $h, $m, $s ) = split /:/, $t, 3;
        $s = 0 if ( !$s );
        $s += $h * 3600;
        $s += $m * 60;
        return $s;
    }

    foreach my $range ( split /,/, $text ) {
        my( $start, $end ) = split /-/, $range;
        push( @retval, [ t2s($start), t2s($end) ] );
    }

    return wantarray ? @retval : \@retval;
}

# ---------------------------------------------------------------------------- #
# opposite of parse_time_range
sub dump_time_range ($) {
    my $range = shift;
    return undef if ( !$range );
    return $range if ( !ref($range) );

    # convert seconds from midnight to Nagios time format
    sub s2t {
        my $s = shift;
        my $hr  = sprintf "%02d", int($s / 3600);
        my $min = $s % 3600;
        my $sec = $min % 60;
        $min = sprintf "%02d", int($min / 60);
        return $sec == 0 ? "$hr:$min" : "$hr:$min:$sec";
    }

    my @retval = ();
    foreach ( @$range ) {
        push( @retval, s2t($_->[0]).'-'.s2t($_->[1]) );
    }
    return join ',', @retval;
}

=item dump()

Output a Nagios define { } block from an object.  This is still EXPERIMENTAL,
but may eventually be robust enough to use for a configuration GUI.

 print $object->dump();

=cut

# ---------------------------------------------------------------------------- #
sub dump {
    my $self = shift;
    my $retval = 'define ';

    $retval .= lc((split /::/, ref($self))[1]) . " {\n";

    foreach my $attribute ( $self->list_attributes ) {
        my $value = $self->$attribute();
        next if ( $attribute eq 'register' && !defined $value );


        my $attrtype = $self->attribute_type( $attribute );

        if ( $attribute eq 'use' ) {
            next if ( !$value || !$value->use ); # root-level template
            $value = $value->use->name;
        }
        elsif ( $attrtype eq 'TIMERANGE' ) {
            $value = dump_time_range( $value );
        }
        # not sure if this is ever used ... might delete it after testing
        # -- tobeya 01/11/2006
        elsif ( $value && !ref($value) && $attrtype =~ /^Nagios::(.*)$/ ) {
            $value = $self->name;
        }


        if ( ref($value) eq 'ARRAY' ) {
            $value = join ', ', map { $_->name } @$value;
        }
        if ( $value ) {
            $retval .= "\t$attribute = $value\n";
        }
        elsif ( !$self->attribute_allows_undef($attribute) ) {
            croak "a required value is undefined";
        }
    }

    $retval .= "}\n";
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
sub name {
    my $self = shift;
    my $name_method = $self->_name_attribute;
    if ( !$self->register ) {
        return $self->{name}->();
    }
    elsif ( ref $name_method eq 'ARRAY' ) {
        my @retval = ();
        for my $idx ( 0..@$name_method-1 ) {
            my $method = $name_method->[$idx];
            $retval[$idx] = $self->$method();
        }
        return \@retval;
    }
    else {
        return $self->$name_method();
    }
}

# ---------------------------------------------------------------------------- #
# not autogenerated, but needs to exist
sub set_name {
    my( $self, $val ) = @_;
    confess "cannot set name of objects with multi-key identity"
        if ( ref $self->{name} eq 'ARRAY' );
    $self->{name} = sub { $val };
}

=item register()

Returns true/undef to indicate whether the calling object is registerable or not.

 if ( $object->register ) { print $object->name, " is registerable." }

=cut

# ---------------------------------------------------------------------------- #
sub register {
    my $self = shift;
    return undef if ( defined $self->{register} && $self->{register}->() == 0 );
    return 1;
}

# not autogenerated, but needs to exist
sub set_register {
    my( $self, $value ) = @_;
    $self->{register} = sub { $value };
}
# ---------------------------------------------------------------------------- #

=item has_attribute()

Returns true/undef to indicate whether the calling object has the attribute specified as the only argument.

 # check to see if $object has attribute "command_line"
 die if ( !$object->has_attribute("command_line") );

=cut

sub has_attribute { exists $nagios_setup{$_[0]->setup_key}->{$_[1]} }

=item list_attributes()

Returns a list of valid attributes for the calling object.

 my @host_attributes = $host->list_attributes();

=cut

sub list_attributes { keys( %{$nagios_setup{$_[0]->setup_key}} ) }

=item attribute_type()

Returns the type of data expected by the object's set_ method for the given attribute.  For some fields like notification_options, it may return "char_flag."

For "name" attributes, it will simply return whatever %setup_data contains.

This method needs some TLC ...

 my $type = $host->attribute_type("notification_period");

=cut

sub attribute_type {
    my $self = $_[0];
#                             self               field type
    my $type = $nagios_setup{$_[0]->setup_key}->{$_[1]}[0];
    if ( ref($type) eq 'ARRAY' ) {
        if ( @$type == 1 ) {
            return $type->[0];
        }
        elsif ( @$type > 1 && length($type->[0]) == 1 ) {
            return "char_flag";
        }
        elsif ( $_[1] eq 'name' ) {
            return $type;
        }
        else {
            croak "bug tobeya\@cpan.org to fix this ...";
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
    my $type = ref($_[0]) ? ref($_[0]) : $_[0];
    return 1 if ( ref $nagios_setup{$_[0]->setup_key}->{$_[1]}[0] eq 'ARRAY' );
    undef;
}

=item attribute_allows_undef()

Returns true if the attribute provided is allowed to have a value of undef.  Setting an attribute to undef will cause the templates to be searched until a non-undef answer is found.

NOTE: this may go away, since I'm not sure if it's really useful at all.

 my $answer = $object->attribute_allows_undef("command_line");

=cut

sub attribute_allows_undef {
    my $type = ref($_[0]) ? ref($_[0]) : $_[0];
    return 1 if ( ${"$type\::valid_fields"}->{$_[1]}[1] != 0 );
    undef;
}

# ---------------------------------------------------------------------------- #
# mostly these are only for use by other Nagios::Modules
sub resolved   {
    if ( $_[1] ) { $_[0]->{_has_been_resolved} = $_[1] }
    return $_[0]->{_has_been_resolved}
}
sub registered {
    if ( $_[1] ) { $_[0]->{_has_been_registered} = $_[1] }
    return $_[0]->{_has_been_registered}
}
sub validate_object_type {
    my $type = lc(ref($_[1]) ? ref($_[1]) : $_[1]);
    $type =~ s/^nagios:://;
    my($result) = grep { /^$type$/i } keys %nagios_setup;
    return defined $result ? "Nagios::$result" : undef;
}
sub list_valid_fields {
    my $type = ref($_[0]) ? ref(shift) : shift;
    $type =~ s/^Nagios:://;
    foreach my $key ( keys %nagios_setup ) {
        if ( lc $key eq lc $type ) {
            return keys %{$nagios_setup{$key}};
        }
    }
    return undef;
}

# ---------------------------------------------------------------------------- #
# a validating set routine used by all of the autogenerated methods
sub _set ($ $ $) {
    my( $self, $key, $value ) = @_;
    croak "$key does not exist for this object ... template?"
        if ( !exists($self->{$key}) );

    my $vf = $nagios_setup{$self->setup_key};

    if ( !$pre_link ) {
        # validate passed in arugments against arrayref in $vf (\%valid_fields)
        $self->_validate( $key, $value, @{$vf->{$key}} );
    }

    # set the value (which is an anonymous subroutine)
    if ( defined($value) ) {
        $self->{$key} = sub { $value };
    }
    else {
        $self->{$key} = undef;
    }
}

# ---------------------------------------------------------------------------- #
# verfiy that the type of an object is what it is supposed to be as specified
# in the hash in BEGIN
sub _validate {
    my( $self, $key, $value, $type, $flags ) = @_;
    #print "--------\@_: ", join(', ', @_), "\n";

    return $value if ( $fast_mode );

    croak "$key is required but is ($value) undefined"
        if ( !defined $value && ($flags & NAGIOS_NO_INHERIT) == NAGIOS_NO_INHERIT );

    return $value if ( !defined $value );

    # types in an arrayref indicate that the value may be a list as well
    # lists may only be of single characters or objects for now
    if ( ref $type eq 'ARRAY' ) {
        # only 1 entry in $type list, so it's probably a class
        if ( @$type == 1 && $type->[0] =~ /^Nagios::.*$/ ) {
            # process single values as an arrayref anyways for consistency
	        if ( ref($value) ne 'ARRAY' ) { $value = [ $value ] }
	        foreach my $val ( @$value ) {
	            croak "object isa '".ref($val)."' when it should be a '$type'"
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
            foreach my $v ( @$value ) {
                croak "\"$v\" is an invalid entry for $key"
                    unless ( exists $possible{$v} );
            }
        }
    }
    elsif ( $type =~ /^Nagios::.*$/ ) {
	    croak "object isa '".ref($value)."' when it should be a '$type'"
	        if ( ref($value) ne $type );
    }
    elsif ( ref($value) eq 'ARRAY' && $type ne 'TIMERANGE' ) {
	    croak "$key cannot have multiple ".ref($value)." values.";
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
	    foreach my $rng ( @$value ) {
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
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# incomplete ..
sub html_widget {
    my( $self, $attribute ) = @_;
    my( $type, $flags ) = @{$nagios_setup{ref $self}->{$attribute}};
    my $retval = '';

croak "not done yet ... bug tobeya at cpan.org";

    sub html_widget_for_type {
        if ( exists $nagios_setup{$_} ) {

        }
        elsif ( $_ eq 'BINARY' ) {
        }
        elsif ( $_ eq 'INTEGER' ) {
        }
        elsif ( $_ eq 'TIMEPERIOD' ) {

        }
    }

    if ( ref $type ) {
        foreach my $subtype ( @$type ) {
            # widget_for_type
        }
    }
    else {
        $retval .= html_widget_for_type();
    }
}
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# This will create classes with methods defined in %nagios_setup at
# compile-time.  In mod_perl, methods will be as fast as hand-written
# equivalents.  Maybe if some methods prove rarely used (likely) it may make
# sense to just use AUTOLOAD and have that instantiate the subroutines, so
# only the first call to a sub is slow
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
        my $pkg = 'Nagios::'.$object;

        # hack $valid_fields into each class
        do { ${$pkg.'::valid_fields'} = $nagios_setup{$object}; };

        # fill in @ISA for each class
        my $isa = do { \@{$pkg.'::ISA'} };
        push( @$isa, 'Nagios::Object' );

        # save off this list of naming (think primary key) attributes
        # access them via method $obj->_name_attribute
        my $name_attr_list = $nagios_setup{$object}->{name}[0];
        *{"$pkg\::_name_attribute"} = sub { $name_attr_list };

        # create methods for each entry in $nagios_setup{$object}
        foreach my $method ( keys(%{$nagios_setup{$object}}) ) {
            next if ( $method eq 'name' );
            # create set_ method
            *{"$pkg\::set_$method"} = sub { shift->_set( $method, @_ ); };

            # create get method
            *{"$pkg\::$method"} = sub {
                return $_[0]->{$method}->() if ref $_[0]->{$method} eq 'CODE';
                if ( ref($_[0]->{use}) eq 'CODE' ) {
                    my $tmpl = $_[0]->{use}->();
                    return $tmpl->{$method}->() if $tmpl->{$method};
                }
            };# end of anonymous "get" subroutine

            # create get method with templates recursively applied
            *{"$pkg\::resolve_$method"} = sub {
                return $_[0]->$method if defined $_[0]->{$method};
                if ( $_[0]->use ) {
                    my $tmpl = $_[0]->use;
                    my $methodname = "resolve_$method";
                    return $tmpl->$methodname;
                }
            };
        }
    }
}

# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #

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

