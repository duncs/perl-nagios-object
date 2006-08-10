###########################################################################
#                                                                         #
# Nagios::Object                                                          #
# Written by Albert Tobey <tobeya@cpan.org>                               #
# Copyright 2003, Albert P Tobey                                          #
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
our @object_types;
our $pre_link = undef;

# THE BEGIN BLOCK IS AT THE BOTTOM OF THIS FILE - MOST OF THE CLASSES' BODIES
# ARE CREATED AT COMPILE-TIME THERE

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
    low_flap_threshhold          => 0,
    high_flap_threshhold         => 0,
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

    # handle the odd-argument call style (used by Nagios::Object::Config)
    if ( $type eq 'Nagios::Object' && scalar(@_) % 2 != 0 ) {
        my $newtype = 'nagios::'. lc(shift);
        ($type) = grep { lc($_) eq $newtype } @object_types;
        croak "invalid type '$newtype/$type' for odd-argument call to new()"
            if ( !$type );
    }

    # reference to the valid fields list defined in BEGIN block
    my $vf = ${$type.'::valid_fields'};
    my %args = @_; # passed-in arguments hash

    # set everything to undef by default
    my %default = map { $_ => undef } keys(%$vf);

    # if pre_link is set, don't set objects' resolved/registered flag
    if ( $pre_link ) {
        $default{_has_been_resolved} = undef;
        $default{_has_been_registered} = undef;
    }
    # _validate will be called by _set, so which will croak if this is wrong
    else {
        $default{_has_been_resolved} = 1;
        $default{_has_been_registered} = 1;
    }

    # instantiate an object
    my $self = bless( \%default, $type );

    # fill in the object with it's data from %args
    # if $pre_link is set, it is expected it will mostly be filled in
    # after instantiation, so probably not much will happen here
    foreach my $key ( keys(%$vf) ) {
        if ( exists($args{$key}) && defined($args{$key}) ) {
            # timeranges must be parsed into ARRAYs, so parse it here so that
            # users don't have to figure out the arrays and so we don't have
            # to export parse_time_range
            if ( $vf->{$key}[0] eq 'TIMERANGE' ) {
                $args{$key} = parse_time_range( $args{$key} );
            }
            # now, use the _set instead of directly setting for consistency
            $self->_set( $key, $args{$key} );
        }
    }

    return $self;
}

# ---------------------------------------------------------------------------- #
# parse the time range text
sub parse_time_range ($) {
    my $text = shift;
    return $text if ( !defined($text) || ref($text) );
    $text =~ s/\s+//g;
    return undef if ( !$text );

    my @retval = ();

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
    my $vf = ${ref($self).'::valid_fields'};

    my $retval = 'define ';

    $retval .= lc((split /::/, ref($self))[1]) . " {\n";

    foreach my $attribute ( $self->list_attributes ) {
        my $value = $self->$attribute();
        next if ( $attribute =~ /(use|register)/ && !$value );

        my $attrtype = $self->attribute_type( $attribute );
        if ( $attrtype eq 'TIMERANGE' ) {
            $value = dump_time_range( $value );
        }
        elsif ( !ref($value) && $attrtype =~ /^Nagios::(.*)$/ ) {
            $value = $self->name;
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

sub has_attribute { exists ${ref($_[0]).'::valid_fields'}->{$_[1]}; }

=item list_attributes()

Returns a list of valid attributes for the calling object.

 my @host_attributes = $host->list_attributes();

=cut

sub list_attributes {
    keys( %${ref($_[0]).'::valid_fields'} );
}

=item attribute_type()

Returns the type of data expected by the object's set_ method for the given attribute.

 my $type = $host->attribute_type("notification_period");

=cut

sub attribute_type {
    my $arref = ${ref($_[0]).'::valid_fields'}->{$_[1]}[0];
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
    return 1 if ( ref ${"$type\::valid_fields"}->{$_[1]}[0] eq 'ARRAY' );
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
sub valid_object_type {
    my $type = ref($_[1]) ? ref($_[1]) : $_[1];
    my($result) = grep { $_ eq $type } @object_types;
    return 1 if ( $result );
}

# ---------------------------------------------------------------------------- #
# a validating set routine used by all of the autogenerated methods
sub _set ($ $ $) {
    my( $self, $key, $value ) = @_;
    croak "$key does not exist for this object ... template?"
        if ( !exists($self->{$key}) );

    my $vf = ${ref($self).'::valid_fields'};

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
    my( $self, $key, $value, $type, $undef_f, $possible ) = @_;

    croak "$key is required but is ($value) undefined"
        if ( !defined $value && $undef_f == 0 );

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
BEGIN {
    # set up a big nasty-looking data structure that'll be used to create all
    # of the objects at run-time ... see the little GENESIS block below
    #   Object => {
    #      attribute => [ Type, Undef Allowed Flag, Nagios ],
    #   }
    # Type: a type for validation _and_ for linking objects, so we know which
    #       fields should point to an object rather than containing a scalar
    # Undef Allowed: some fields can be set to undef and be inherited from
    #                template objects
    # Nagios Flag: Some fields arent' really part of nagios, in which case
    #              this should be set to 0.  The methods will still be created
    #              but the field will be skipped when dumping Nagios configs
    #              and during various other operations where we want strictly
    #              real Nagios fields
    my %_nagios_setup = (
        Service => {
            use                           => ['Nagios::Service',         0, 1],
            service_description           => ['STRING',                  0, 1],
			host_name                     => [['Nagios::Host'],          0, 1],
			hostgroup_name                => [['Nagios::HostGroup'],     0, 1],
			is_volatile                   => ['BINARY',                  0, 1],
			check_command                 => ['Nagios::Command',         0, 1],
			max_check_attempts            => ['INTEGER',                 0, 1],
			normal_check_interval         => ['INTEGER',                 0, 1],
			retry_check_interval          => ['INTEGER',                 0, 1],
			active_checks_enabled         => ['BINARY',                  0, 1],
			passive_checks_enabled        => ['BINARY',                  0, 1],
			check_period                  => ['Nagios::TimePeriod',      1, 1],
			parallelize_check             => ['BINARY',                  0, 1],
			obsess_over_service           => ['BINARY',                  0, 1],
			check_freshness               => ['BINARY',                  0, 1],
			freshness_threshhold          => ['INTEGER',                 0, 1],
			event_handler                 => ['Nagios::Command',         0, 1],
			event_handler_enabled         => ['BINARY',                  0, 1],
			low_flap_threshhold           => ['INTEGER',                 0, 1],
			high_flap_threshhold          => ['INTEGER',                 0, 1],
			flap_detection_enabled        => ['BINARY',                  0, 1],
			process_perf_data             => ['BINARY',                  0, 1],
			retain_status_information     => ['BINARY',                  0, 1],
			retain_nonstatus_information  => ['BINARY',                  0, 1],
			notification_period           => ['Nagios::TimePeriod',      1, 1],
			notification_interval         => ['Nagios::TimePeriod',      1, 1],
            notification_options          => [[qw(u w c r)],             0, 1],
            contact_groups                => [['Nagios::ContactGroup'],  0, 1],
            notifications_enabled         => ['BINARY',                  0, 1],
			stalking_options              => [[qw(o w u c)],             0, 1],
            name                          => ['service_description',     0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        Host => {
		    use                           => ['Nagios::Host',            0, 1],
		    host_name                     => ['STRING',                  0, 1],
		    alias                         => ['STRING',                  0, 1],
		    address                       => ['STRING',                  0, 1],
		    parents                       => [['Nagios::Host'],          1, 1],
		    check_command                 => ['STRING',                  0, 1],
		    max_check_attempts            => ['INTEGER',                 0, 1],
		    checks_enabled                => ['BINARY',                  0, 1],
		    event_handler                 => ['STRING',                  0, 1],
		    event_handler_enabled         => ['BINARY',                  0, 1],
		    low_flap_threshhold           => ['INTEGER',                 0, 1],
		    high_flap_threshhold          => ['INTEGER',                 0, 1],
		    flap_detection_enabled        => ['BINARY',                  0, 1],
		    process_perf_data             => ['BINARY',                  0, 1],
		    retain_status_information     => ['BINARY',                  0, 1],
		    retain_nonstatus_information  => ['BINARY',                  0, 1],
		    notification_period           => [['Nagios::TimePeriod'],    0, 1],
		    notification_interval         => [['Nagios::TimePeriod'],    0, 1],
		    notification_options          => [[qw(d u r)],               0, 1],
		    notifications_enabled         => ['BINARY',                  0, 1],
		    stalking_options              => [[qw(o d u)],               0, 1],
            name                          => ['host_name',               0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        HostGroup => {
		    use                           => ['Nagios::HostGroup',       0, 1],
            hostgroup_name                => ['STRING',                  0, 1],
	        alias                         => ['STRING',                  0, 1],
	        contact_groups                => [['Nagios::ContactGroup'],  0, 1],
	        members	                      => [['Nagios::Host'],          0, 1],
            name                          => ['hostgroup_name',          0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        Contact => {
            use                           => ['Nagios::Contact',         0, 1],
            contact_name                  => ['STRING',                  0, 1],
	        alias                         => ['STRING',                  0, 1],
	        host_notification_period      => ['Nagios::TimePeriod',      0, 1],
			service_notification_period   => ['Nagios::TimePeriod',      0, 1],
	        host_notification_options     => [[qw(d u r n)],             0, 1],
			service_notification_options  => [[qw(w u c r n)],           0, 1],
			host_notification_commands    => [['Nagios::Command'],       0, 1],
			service_notification_commands => [['Nagios::Command'],       0, 1],
			email                         => ['STRING',                  0, 1],
			pager                         => ['STRING',                  0, 1],
            name                          => ['contact_name',            0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        ContactGroup => {
		    use                           => ['Nagios::ContractGroup',   0, 1],
            contactgroup_name             => ['STRING',                  0, 1],
	        alias                         => ['STRING',                  0, 1],
	        members	                      => [['Nagios::Contact'],       0, 1],
            name                          => ['contactgroup_name',       0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        Command => {
		    use                           => ['Nagios::Command',         0, 1],
            command_name                  => ['STRING',                  0, 1],
            command_line                  => ['STRING',                  0, 1],
            name                          => ['command_name',            0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        TimePeriod => {
            use                           => ['Nagios::TimePeriod',      0, 1],
			timeperiod_name               => ['STRING',                  0, 1],
            alias                         => ['STRING',                  0, 1],
            sunday                        => ['TIMERANGE',               0, 1],
            monday                        => ['TIMERANGE',               0, 1],
            tuesday                       => ['TIMERANGE',               0, 1],
            wednesday                     => ['TIMERANGE',               0, 1],
            thursday                      => ['TIMERANGE',               0, 1],
            friday                        => ['TIMERANGE',               0, 1],
            saturday                      => ['TIMERANGE',               0, 1],
            name                          => ['timeperiod_name',         0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        }, 
        ServiceEscalation => {
		    use                           => ['Nagios::ServiceEscalation',0,1],
			host_name                     => ['Nagios::Host',            0, 1],
			service                       => ['Nagios::Service',         0, 1],
	        contact_groups                => [['Nagios::ContactGroup'],  0, 1],
            first_notification            => ['INTEGER',                 0, 1],
	        last_notification             => ['INTEGER',                 0, 1],
	        notification_interval         => ['INTEGER',                 0, 1],
            name                          => [['host_name','service'],   0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        ServiceDependency => {
		    use                           => ['Nagios::ServiceDependency',0,1],
            dependent_host                => ['Nagios::Host',            0, 1],
	        dependent_service             => ['Nagios::Service',         0, 1],
			host_name                     => ['Nagios::Host',            0, 1],
			service                       => ['Nagios::Service',         0, 1],
			execution_failure_criteria    => [[qw(o w u c n)],           0, 1],
			notification_failure_criteria => [[qw(o w u c n)],           0, 1],
            name                          => [[qw(dependent_host
                                                  dependent_service
                                                  host_name
                                                  service)],             0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        HostEscalation => {
		    use                           => ['Nagios::HostEscalation',  0, 1],
			host_name                     => ['Nagios::Host',            0, 1],
	        contact_groups                => [['Nagios::ContactGroup'],  0, 1],
            first_notification            => ['INTEGER',                 0, 1],
	        last_notification             => ['INTEGER',                 0, 1],
	        notification_interval         => ['INTEGER',                 0, 1],
            name                          => ['host_name',               0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        HostDependency => {
		    use                           => ['Nagios::HostDependency',  0, 1],
            dependent_host                => ['Nagios::Host',            0, 1],
			host_name                     => ['Nagios::Host',            0, 1],
			notification_failure_criteria => [[qw(o w u c n)],           0, 1],
            name                          => [['host_name','dependent_host'],
                                                                         0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        },
        HostGroupEscalation => {
		    use                           => ['Nagios::HostGroupEscalation',
                                                                         0, 1],
			hostgroup_name                => ['Nagios::HostGroup',       0, 1],
	        contact_groups                => [['Nagios::ContactGroup'],  0, 1],
            first_notification            => ['INTEGER',                 0, 1],
	        last_notification             => ['INTEGER',                 0, 1],
	        notification_interval         => ['INTEGER',                 0, 1],
            name                          => ['hostgroup_name',          0, 0],
            comment                       => ['comment',                 0, 0],
            file                          => ['filename',                0, 0]
        }
    );

    # create classes with methods defined in _nagios_setup at compile-time
    # in mod_perl, methods will be as fast as hand-written equivalents
    # Maybe if some methos prove rarely used (likely) it may make sense
    # to just use AUTOLOAD and have that instantiate the subroutines, so only
    # the first call to a sub is slow
    GENESIS: {
        no warnings;

        # create a package for every key in %_nagios_setup
        foreach my $object ( keys(%_nagios_setup) ) {
            # create a package name
            my $pkg = 'Nagios::'.$object;
            push( @object_types, $pkg );

            # hack $valid_fields into each class
            do { ${$pkg.'::valid_fields'} = $_nagios_setup{$object}; };

            # fill in @ISA for each class
            my $isa = do { \@{$pkg.'::ISA'} };
            push( @$isa, 'Nagios::Object' );

            # save off this list of naming (think primary key) attributes
            # access them via method $obj->_name_attribute
            my $name_attr_list = $_nagios_setup{$object}->{name}[0];
            *{"$pkg\::_name_attribute"} = sub { $name_attr_list };

            # create methods for each entry in $_nagios_setup{$object}
            foreach my $method ( keys(%{$_nagios_setup{$object}}) ) {
                next if ( $method eq 'name' );
                # create set_ method
                *{"$pkg\::set_$method"} = sub { shift->_set( $method, @_ ); };

                # create get method
                *{"$pkg\::$method"} = sub {
                    return $_[0]->{$method}->() if defined $_[0]->{$method};
                    if ( ref($_[0]->{use}) eq 'CODE' ) {
                        my $tmpl = $_[0]->{use}->();
                        return $tmpl->{$method}->() if $tmpl->{$method};
                    }
                };# end of anonymous "get" subroutine
            }
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

