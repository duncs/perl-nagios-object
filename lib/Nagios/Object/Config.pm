###########################################################################
#                                                                         #
# Nagios::Object::Config                                                  #
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
package Nagios::Object::Config;
use strict;
use warnings;
use Nagios::Object qw(:all %nagios_setup);
use Symbol;
use Carp;

our $fast_mode = undef;

=head1 NAME

Nagios::Object::Config

=head1 DESCRIPTION

This is a module for parsing and processing Nagios object configuration files into perl objects.

=head1 METHODS

=over 4

=item new()

Create a new configuration object.  If Version is not specified, the already weak
validation will be weakened further to allow mixing of Nagios 1.0 and 2.0 configurations.
For now, the minor numbers of Version are ignored.  Do not specify any letters as in '2.0a1'.

 my $objects = Nagios::Object::Config->new();
 my $objects = Nagios::Object::Config->new( Version => 1.2 );
 my $objects = Nagios::Object::Config->new( Version => 2.0 );

=cut

sub new {
    my $class = ref($_[0]) ? ref(shift) : shift;
    my $self = {
        config_files    => [],
        host_list       => [],
        contact_list    => [],
        command_list    => [],
        service_list    => [],
        hostgroup_list  => [],
        timeperiod_list => [],
        contactgroup_list        => [],
        hostdependency_list      => [],
        hostescalation_list      => [],
        servicedependency_list   => [],
        serviceescalation_list   => [],
        hostgroupescalation_list => []
    };

    # parse arguments passed in
    if ( @_ % 2 == 0 ) {
        my %args = ();
        for ( my $i=0; $i<@_; $i+=2 ) {
            $args{lc $_[$i]} = $_[$i+1];
        }

        # set up limited Nagios v1/v2 validation
        if ( !$fast_mode && $args{version} ) {
            if ( $args{version} >= 2 ) {
                $self->{nagios_version} = NAGIOS_V2;
                # remove keys from nagios_setup that are invalid for V2
                foreach my $key ( keys %nagios_setup ) {
                    if ( ($nagios_setup{$key}->{use}[1] & NAGIOS_V1_ONLY) == NAGIOS_V1_ONLY ) {
                        delete $nagios_setup{$key}
                    }
                }
            }
            elsif ( $args{version} < 2 ) {
                $self->{nagios_version} = NAGIOS_V1;
                # remove keys from nagios_setup that are invalid for V1
                foreach my $key ( keys %nagios_setup ) {
                    if ( ($nagios_setup{$key}->{use}[1] & NAGIOS_V2) == NAGIOS_V2 ) {
                        delete $nagios_setup{$key}
                    }
                }
            }
        }
        else {
            $self->{nagios_version} = undef;
        }
    }
    else {
        croak "Single argument form of this constructor is not supported.\n",
              "Try: Nagios::Object::Config->new( Version => 2 );";
    }

    return bless( $self, $class );
}

sub fast_mode {
    if ( $_[1] ) { $fast_mode = $_[1] }
    return $fast_mode;
}

=item parse()

Parse a nagios object configuration file into memory.  Although Nagios::Objects will be created, they are not really usable until the register() method is called.

 $parser->parse( "myfile.cfg" );

=cut

# TODO: add checks for undefined values where prohibited in GENESIS hash
sub parse {
    my( $self, $filename ) = @_;
    croak "cannot read file '$filename': $!" unless ( -r $filename );

    $Nagios::Object::pre_link = 1;

    # $file_idx is for tracking source files so modified
    # configurations can be written out to the same files
    my $file_idx = push( @{$self->{config_files}}, $filename ) - 1;

	my $fh = gensym();
	open( $fh, "<$filename" )
	    || croak "could not open $filename for reading: $!";

    our $line_no = 0;
	sub strippedline {
	    $line_no++;
	    return undef if ( eof($_[0]) );
	    my $line = readline($_[0]);
	    $line =~ s/[\r\n\s]+$//; # remove trailing whitespace and CRLF
	    $line =~ s/^\s+//;       # remove leading whitespace
	    return ' ' if ( $line =~ /^[#;]/ ); # skip/delete comments
	    return $line || ' '; # empty lines are a single space
	}

	my( $append, $type, $current, $in_definition ) = ( '', '', {}, undef );
	while ( my $line = strippedline($fh) ) {
	    # skip empty lines
	    next if ( $line eq ' ' );
	
	    # append saved text to the current line
	    if ( $append ) {
	        if ( $append !~ / $/ && $line !~ /^ / ) { $append .= ' ' }
	        $line = $append . $line;
	        $append = undef;
	    }
	
	    # end of object definition
	    if ( $line =~ /}(.*)$/ ) {
	        $in_definition = undef;
            # continue parsing after closing object with text following the '}'
            $append = $1;
            next;
	    }
	    # beginning of object definition
	    elsif ( $line =~ /define (\w+) ?{(.*)$/ ) {
	        $type = $1;
	        if ( $in_definition ) {
	            croak "Error: Unexpected start of object definition in file '$filename' on line $line_no.  Make sure you close preceding objects before starting a new one.\n";
            }
            elsif ( !Nagios::Object->validate_object_type($type) ) {
	            croak "Error: Invalid object definition type '$type' in file '$filename' on line $line_no.\n";
	        }
            else {
		        $current = Nagios::Object->new( Type => Nagios::Object->validate_object_type($type) );
                push( @{$self->{$type.'_list'}}, $current );
	            $in_definition = 1;
                $append = $2;

                # save a reference to this Nagios::Object::Config for later use
                # outside this module (it's needed for accessing the big linked data
                # structure)
                $current->{object_config_object} = $self;

                next;
            }
	    }
        # save whatever's left in the buffer for the next iteration
	    elsif ( !$in_definition ) {
	        $append = $line;
	        next;
	    }
        # this is an attribute inside an object definition
        elsif ( $in_definition ) {
            $line =~ s/\s*;(.*)$//;

            # the comment stripped off of $line is saved in $1 due to the ()
            # around .*, so it's saved in the object if supported
            if ( !$fast_mode && $1 && $current->can('set_comment') ) {
                $current->set_comment( $1 );
            }

            my( $key, $val ) = split( /\s+/, $line, 2 );
            my $set_method = 'set_'.$key;
            croak "\"$key\" is invalid or module out of date: no such method \"$set_method\""
                if ( !$current->can( $set_method ) );
	        $current->$set_method( $val );
	    }
        else {
            croak "Error: Unexpected token in file '$filename' on line $line_no.\n";
        }
	}

    if ( $in_definition ) {
        croak "Error: Unexpected EOF in file '$filename' on line $line_no - check for a missing closing bracket.\n";
    }
	
	close( $fh );

    return 1;
}

=item find_object()

Search through the list of objects' names and return the first match. 
The second argument is optional.  Always using it can considerably reduce
the size of the list to be searched, so it is recommended.

 my $object = $parser->find_object( "localhost" );
 my $object = $parser->find_object( "oracle", "Nagios::Service" );

=cut

sub find_object {
    my( $self, $name, $type ) = @_;
    $type = $type->new();    
}

=item find_attribute()

Search through the objects parsed thus far, looking for a particular textual name.  When found, return that object.  If called with two arguments, it will search through all objects currently loaded until a match is found.  A third argument may specify the type of object to search for, which may speed up the search considerably.

 my $object = $parser->find_attribute( "command_name", "check_host_alive" );
 my $object = $parser->find_attribute( "command_name", "check_host_alive", 'Nagios::Host' );

=cut

sub find_attribute {
    my( $self, $attribute, $what, $type ) = @_;
    confess "must specify what string to find_attribute" if ( !$what && $what != 0 );

    my @to_search = ();
    if ( defined $type && $type =~ /^Nagios::(.*)$/ ) {
        $to_search[0] = lc($1);
    }
    else {
        # brute-force search through all objects of all types
        @to_search = map { lc $_ } keys %nagios_setup;
    }

    foreach my $type ( @to_search ) {
        foreach my $candidate ( @{$self->{"${type}_list"}} ) {
            return $candidate if ( $candidate->name eq $what );
        }
    }
}

=item resolve()

Resolve the template for the specified object.  Templates will not work until this has been done.

 $parser->resolve( $object );

=cut

sub resolve {
    my( $self, $object ) = @_;

    # return if this object has already been resolved
    return 1 if ( $object->resolved );

    # set the resolved flag
    $object->resolved(1);

    if ( $object->has_attribute('use') && $object->use ) {
        my $template = $self->find_attribute( 'use', $object->use, ref $object );
        $object->_set( 'use', $template );
    }

    1;
}

=item register()

Examine all attributes of an object and link all of it's references to other Nagios objects to their respective perl objects.  If this isn't called, some methods will return the textual name instead of a perl object.

 $parser->register( $host_object );
 my $timeperiod_object = $host_object->notification_period;

=cut

sub register {
    my( $self, $object ) = @_;

    # bail out if this object has already been registered
    return 1 if ( $object->registered );

    # bail out if we shouldn't register this object
    return 1 if ( !$object->register );

    # bad things(tm) will happen if resolve hasn't been called
    croak "must call resolve() method on object before registering"
        if ( !$object->resolved );

    # go through all of the object's attributes and link them to objects
    # where appropriate
    foreach my $attribute ( $object->list_attributes ) {
        next if ( $attribute eq 'use' || $attribute eq 'register' );

        next if ( !defined $object->$attribute() );

        my $attr_type = $object->attribute_type($attribute);
        if ( ref $attr_type eq 'ARRAY' ) {
            $attr_type = $attr_type->[0];
        }
        if ( $attr_type =~ /^Nagios::(.*)$/ ) {
            if ( $object->attribute_is_list($attribute) ) {
                my @to_find = split /\s*,\s*/, $object->$attribute();
                my @found = ();
                foreach my $item ( @to_find ) {
                    my $ref = $self->find_attribute( $attribute, $item );
                    push( @found, $ref ) if ( $ref );
                }

                if ( @to_find != @found ) {
                    confess "Could not link all elements (",$object->$attribute(),") for attribute '$attribute'.  Check your configuration file for referenced objects that are not defined."
                }
                $object->_set( $attribute, \@found );
            }
            else {
                my $ref = $self->find_attribute( $attribute, $object->$attribute(), $attr_type );
                $object->_set( $attribute, $ref ) if ( $ref );
            }

        }
    }

    $object->registered(1);
}

=item resolve_objects()

Resolve all objects currently loaded into memory.  This can be called any number of times without corruption.

 $parser->resolve_objects();

=cut

sub resolve_objects {
    my $self = shift;

    foreach my $obj_type ( map { lc $_ } keys %nagios_setup ) {
        foreach my $object ( @{$self->{$obj_type.'_list'}} ) {
            $self->resolve( $object );
        }
    }
    return 1;
}

=item register_objects()

Same deal as resolve_objects(), but as you'd guess, it registers all objects currently loaded into memory.

 $parser->register_objects();

=cut

sub register_objects {
    my $self = shift;

    foreach my $obj_type ( map { lc $_ } keys %nagios_setup ) {
        foreach my $object ( @{$self->{$obj_type.'_list'}} ) {
            $self->register( $object );
        }
    }

    $Nagios::Object::pre_link = undef;
    return 1;
}

=item list_hosts(), list_hostgroups(), etc.

Returns an array/arrayref of objects of the given type.

 ->list_hosts;
 ->list_hostroups;
 ->list_services;
 ->list_timeperiods;
 ->list_commands;
 ->list_contacts;
 ->list_contactgroups;
 ->list_hostdependencies;
 ->list_servicedependencies;
 ->list_hostescalation;
 ->list_hostgroupescalation;
 ->list_serviceescalation;

=cut

# may want to change this eventually to return a copy of the array
# instead of the array referenced in $self
sub _list {
    my( $self, $type ) = @_;
    my $key = $type . '_list';
    wantarray ? @{$self->{$key}} : $self->{$key};
}

sub list_hosts                { shift->_list('host') }
sub list_hostgroups           { shift->_list('hostgroup') }
sub list_services             { shift->_list('service') }
sub list_timeperiods          { shift->_list('timeperiod') }
sub list_commands             { shift->_list('command') }
sub list_contacts             { shift->_list('contacts') }
sub list_contactgroups        { shift->_list('contactgroup') }
sub list_hostdependencies     { shift->_list('hostdependency') }
sub list_servicedependencies  { shift->_list('servicedependency') }
sub list_hostescalation       { shift->_list('hostescalation') }
sub list_hostgroupescalations { shift->_list('hostgroupescalation') }
sub list_serviceescalations   { shift->_list('serviceescalation') }

# --------------------------------------------------------------------------- #
# extend Nagios::Host - requires methods provided in this file
# --------------------------------------------------------------------------- #

# really slow, brute force way of listing services
sub Nagios::Host::list_services {
    my $self = shift;
    my $conf = $self->{object_config_object};

    my @retval = ();
    foreach my $s ( $conf->list_services ) {
        next if ( !$s->service_description );
        if ( $s->host_name ) {
            foreach my $h ( @{$s->host_name} ) {
                if ( $h->host_name eq $self->host_name ) {
                    push( @retval, $s );
                }
            }
        }
        if ( $s->hostgroup_name ) {
            foreach my $hg ( @{$s->hostgroup_name} ) {
                foreach my $h ( @{$hg->members} ) {
                    if ( $h->host_name eq $self->host_name ) {
                        push( @retval, $s );
                    }
                }
           }
        }
    }
    return @retval;
}

# I use a patched version of Nagios right now, so I need these to
# keep the parser from bombing when I test on my config. (Al Tobey)
sub Nagios::Host::snmp_community { }
sub Nagios::Host::set_snmp_community { }

1;

