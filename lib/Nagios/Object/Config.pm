###########################################################################
#                                                                         #
# Nagios::Object::Config                                                  #
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
package Nagios::Object::Config;
use strict;
use warnings;
use Nagios::Object qw(:all %nagios_setup);
use Scalar::Util qw(blessed);
use File::Basename qw(dirname);
use File::Find qw(find);
use Symbol;
use Carp;

# NOTE: due to CPAN version checks this cannot currently be changed to a
# standard version string, i.e. '0.21'
our $VERSION     = '41';
our $fast_mode   = undef;
our $strict_mode = undef;

=head1 NAME

Nagios::Object::Config - Perl objects to represent Nagios configuration

=head1 DESCRIPTION

This is a module for parsing and processing Nagios object configuration files into perl objects.

=head1 METHODS

=over 4

=item new()

Create a new configuration object.  If Version is not specified, the already weak
validation will be weakened further to allow mixing of Nagios 1.0 and 2.0 configurations.
For now, the minor numbers of Version are ignored.  Do not specify any letters as in '2.0a1'.

To enable regular expression matching, use either the "regexp_matching" or "true_regexp_matching"
arguments to new().    See enable_regexp_matching() and enable_true_regexp_matching() below.

 my $objects = Nagios::Object::Config->new();
 my $objects = Nagios::Object::Config->new( Version => 1.2 );

 my $objects = Nagios::Object::Config->new(
                    Version => 2.0,
                    regexp_matching => 1,
                    true_regexp_matching => 2
 );

=cut

sub new {
    my $class = ref( $_[0] ) ? ref(shift) : shift;
    my $self = {
        regexp_matching      => undef,
        true_regexp_matching => undef,
        config_files         => []
    };

    # initialize lists and indexes e.g. host_list, command_index, etc.
    foreach my $class ( keys %nagios_setup ) {
        $self->{ lc($class) . '_list' } = [];
        $self->{ lc($class) . '_index' } = {};
    }

    # parse arguments passed in
    if ( @_ % 2 == 0 ) {
        my %args = ();
        for ( my $i = 0; $i < @_; $i += 2 ) {
            $args{ lc $_[$i] } = $_[ $i + 1 ];
        }

        # set up limited Nagios v1/v2 validation
        if ( !$fast_mode && $args{version} ) {
            if ( $args{version} >= 2 ) {
                $self->{nagios_version} = NAGIOS_V2;

                # remove keys from nagios_setup that are invalid for V2
                foreach my $key ( keys %nagios_setup ) {
                    if ( ( $nagios_setup{$key}->{use}[1] & NAGIOS_V1_ONLY )
                        == NAGIOS_V1_ONLY )
                    {
                        delete $nagios_setup{$key};
                    }
                }
            }
            elsif ( $args{version} < 2 ) {
                $self->{nagios_version} = NAGIOS_V1;

                # remove keys from nagios_setup that are invalid for V1
                foreach my $key ( keys %nagios_setup ) {
                    if ( ( $nagios_setup{$key}->{use}[1] & NAGIOS_V2 )
                        == NAGIOS_V2 )
                    {
                        delete $nagios_setup{$key};
                    }
                }
            }
        }
        else {
            $self->{nagios_version} = undef;
        }

        if ( $args{regexp_matching} ) {
            $self->{_regexp_matching_enabled} = 1;
        }
        elsif ( $args{true_regexp_matching} ) {
            $self->{_regexp_matching_enabled}      = 1;
            $self->{_true_regexp_matching_enabled} = 1;
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

sub strict_mode {
    if ( $_[1] ) { $strict_mode = $_[1] }
    return $strict_mode;
}

=item parse()

Parse a nagios object configuration file into memory.  Although Nagios::Objects will be created, they are not really usable until the register() method is called.

 $parser->parse( "myfile.cfg" );

=cut

# TODO: add checks for undefined values where prohibited in %nagios_setup
# Note: many things that look a little inefficient or weird can probably
# be traced back to the C source for Nagios, since the original parser
# was a perl-ized version of that code.   I'm (tobeya) working on a new
# one that should be faster and more tolerant of broken configs, but it
# needs a lot of testing before going to CPAN.
sub parse {
    my ( $self, $filename ) = @_;

    $Nagios::Object::pre_link = 1;

    my $fh = gensym();
    open( $fh, "<$filename" )
        || croak "could not open $filename for reading: $!";

    our $line_no = 0;

    my $dirname = dirname($filename);

    sub strippedline {
        $line_no++;
        return undef if ( eof( $_[0] ) );
        my $line = readline( $_[0] );
        $line =~ s/[\r\n\s]+$//;    # remove trailing whitespace and CRLF
        $line =~ s/^\s+//;          # remove leading whitespace
        return ' ' if ( $line =~ /^[#;]/ );    # skip/delete comments
        return $line || ' ';    # empty lines are a single space
    }

    my ( $append, $type, $current, $in_definition ) = ( '', '', {}, undef );
    while ( my $line = strippedline($fh) ) {

        # append saved text to the current line
        if ($append) {
            $line = '' unless $line;
            if ( $append !~ / $/ && $line !~ /^ / ) { $append .= ' ' }
            $line   = $append . $line;
            $append = undef;
        }

	if ( $line && $line =~ /\\$/ )
	{	#Continued line (ends in a '\')
		#Remove \, append to $append, and let next iteration handle it
		$line =~ s/\s*\\$//;
		$append = $line;
		next;
	}

        # skip empty lines (don't do earlier because may get stuff prepended)
        next if ( $line eq ' ' );

        if ( $line =~ /(include|cfg)_file\s*=\s*([\w\-\/\\\:\.]+)/ ) {
            my $incfile = $2;
            $self->parse("$dirname/$incfile") if -f "$dirname/$incfile";
            next;
        }
        if ( $line =~ /(include|cfg)_dir\s*=\s*([\w\-\/\\\:\.]+)/ ) {
            my $incdir = $2;

            find(sub { $self->parse($_) if ($_=~/\.cfg$/ && -f $_); }, "$dirname/$incdir") if -d "$dirname/$incdir";
            next;
        }

# end of object definition
# Some object attributes are strings, which can contain a right-curly bracket and confuse this parser:
#  - The proper fix would be to make the parser sensitive to arbitrary string attributes, but I will just
#    do it the easy way for now and assume there is no more text on the same line after the right-curly
#    bracket that closes the object definition.
#if ( $line =~ /}(.*)$/ ) {
        if ( $line =~ /}(\s*)$/ ) {
            $in_definition = undef;

           # continue parsing after closing object with text following the '}'
            $append = $1;
            next;
        }

        # beginning of object definition
        elsif ( $line =~ /define\s+(\w+)\s*{?(.*)$/ ) {
            $type = $1;
            if ($in_definition) {
                croak "Error: Unexpected start of object definition in file "
                    . "'$filename' on line $line_no.  Make sure you close "
                    . "preceding objects before starting a new one.\n";
            }
            elsif ( !Nagios::Object->validate_object_type($type) ) {
                croak
                    "Error: Invalid object definition type '$type' in file '$filename' on line $line_no.\n";
            }
            else {
                $current = Nagios::Object->new(
                    Type => Nagios::Object->validate_object_type($type) );
                push( @{ $self->{ $type . '_list' } }, $current );
                $in_definition = 1;
                $append        = $2;

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
        elsif ($in_definition) {
            $line =~ s/\s*;(.*)$//;
            my $comment = $1;

            # the comment stripped off of $line is saved in $1 due to the ()
            # around .*, so it's saved in the object if supported
            if ( !$fast_mode && $1 && $current->can('set_comment') ) {
                $current->set_comment($comment);
            }

            my ( $key, $val ) = split( /\s+/, $line, 2 );
            my $set_method = 'set_' . $key;
            if ( $current->can($set_method) ) {
                # Put back the comment if we have a notes key.
                $val .= ';' . $comment if ( $key eq 'notes' && defined $comment );
                $current->$set_method($val);
            }
            elsif ($strict_mode) {
                confess "Invalid attribute: \"$key\".  Could not find "
                    . ref($current)
                    . "::$set_method.   Try disabling strict_mode? (see: perldoc Nagios::Object::Config)";
            }

            # fall back to simple scalar storage with even less verification
            # - this is the bit that lets me slack off between Nagios releases
            # because it'll let new options "just work" for most cases - the
            # rest can send in bug reports, rather than the majority
            else {
                $nagios_setup{ $current->setup_key }->{$key}
                    = [ 'STRING', 0 ];
                $current->{$key} = $val;
            }

            # Add to the find_object search hash.
            if ( $key eq 'name' || $key eq $nagios_setup{ $current->setup_key }->{'name'}[0] ) {
                push( @{ $self->{ lc($current->setup_key) . '_index' }->{$val} }, $current );
            }
        }
        else {
            croak
                "Error: Unexpected token in file '$filename' on line $line_no.\n";
        }
    }

    if ($in_definition) {
        croak
            "Error: Unexpected EOF in file '$filename' on line $line_no - check for a missing closing bracket.\n";
    }

    close($fh);

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
    my ( $self, $name, $type ) = @_;

    my $searchlist;
    if ( $type && $type =~ /^Nagios::/ ) {
        my @objl = $self->find_objects($name, $type);
        return $objl[0] if ( scalar @objl );
    }
    elsif ( !$type ) {
        $searchlist = $self->all_objects;

        foreach my $obj (@$searchlist) {

          #printf STDERR "obj name '%s', name searched '%s'\n", $obj->name, $name;
            my $n = $obj->name;
            if ( $n && $n eq $name ) {
                return $obj;
            }
        }
    }
}

=item find_objects()

Search through the list of objects' names and return all the matches. 
The second argument is required.

 my @object_list = $parser->find_objects( "load", "Nagios::Service" );

=cut

sub find_objects {
    my ( $self, $name, $type ) = @_;

    if ( $type && $type =~ /^Nagios::(.*)/ ) {
        my $index_type = lc($1) . '_index';
        if ( exists $self->{$index_type} && exists $self->{$index_type}->{$name} ) {
             return @{$self->{$index_type}->{$name}};
        }
    }
    return ();
}

=item find_objects_by_regex()

Search through the list of objects' names and return a list of matches.
The first argument will be evaluated as a regular expression.   The second
argument is required and specifies what kind of object to search for.

The regular expressions are created by translating the "*" to ".*?" and "?"
to ".".   For now (v0.9), this code completely ignores Nagios's use_regexp_matching
and use_true_regexp_matching and does full RE matching all the time.

 my @objects = $parser->find_objects_by_regex( "switch_*", "Nagios::Host" );
 my @objects = $parser->find_objects_by_regex( "server0?", "Nagios::Host" );

=cut

sub find_objects_by_regex {
    my ( $self, $re, $type ) = @_;
    my @retval;

    my $searchlist;
    if ( !$type ) {
        $searchlist = $self->all_objects;
    }
    else {
        $searchlist = $self->all_objects_for_type($type);
    }

    foreach my $obj (@$searchlist) {
        my $objname = $obj->name;
        if ( $objname && $objname =~ /$re/ ) {
            push @retval, $obj;
        }
    }
    return @retval;
}

=item all_objects_for_type()

Obtain a reference to all objects of the specified Nagios object type.

Usage: $objects = all_objects_for_type($object_type)

Parameters:
    $object_type - A specific Nagios object type, i.e. "Nagios::Contact"..

Returns:
    A reference to an array of references to all objects of the specified
    type associated with this configuration.  Objects of this type added
    to the configuration following the call to this method _will_ be
    accessible through this reference after the fact.

    Note that the array reference by the return value may be empty.

Example:

    my $contacts = $config->all_objects_for_type("Nagios::Contact");
    if (scalar(@$contacts) == 0) {
        print "No contacts have yet been defined\n";
    } else {
        foreach $contact (@$contacts) {
            ...
        }
    }

=cut

sub all_objects_for_type {
    my ( $self, $obj_type ) = @_;

    my $ret_array = [];

    confess
        "must specify Nagios object type to all_objects_for_type('$obj_type')"
        unless ( $obj_type =~ /^Nagios::(.*)$/ );

    # e.g. service_list is an arrayref in $self - just return it
    my $list_type = lc($1) . '_list';
    if ( exists $self->{$list_type} ) {
        $ret_array = $self->{$list_type};
    }
    return $ret_array;
}

=item all_objects()

Returns an arrayref with all objects parsed from the config in it.

 my $everything = $config->all_objects;

=cut

sub all_objects {
    my $self = shift;
    my @ret_array;

    # a little cheesy, but less maintenance goofups
    foreach my $key ( keys %$self ) {
        next unless $key =~ /_list$/ && ref $self->{$key} eq 'ARRAY';
        push @ret_array, @{ $self->{$key} };
    }
    return \@ret_array;
}

=item find_attribute()

Search through the objects parsed thus far, looking for a particular textual name.  When found, return that object.  If called with two arguments, it will search through all objects currently loaded until a match is found.  A third argument may specify the type of object to search for, which may speed up the search considerably.

 my $object = $parser->find_attribute( "command_name", "check_host_alive" );
 my $object = $parser->find_attribute( "command_name", "check_host_alive", 'Nagios::Host' );

=cut

sub find_attribute {
    my ( $self, $attribute, $what, $type ) = @_;
    confess "must specify what string to find_attribute"
        if ( !$what && $what != 0 );

    my @to_search = ();
    if ( defined $type && $type =~ /^Nagios::(.*)$/ ) {
        $to_search[0] = lc($1);
    }
    else {

        # brute-force search through all objects of all types
        @to_search = map { lc $_ } keys %nagios_setup;
    }

    foreach my $type (@to_search) {
        foreach my $obj ( @{ $self->{"${type}_list"} } ) {
            if (   $obj->has_attribute($attribute)
                && $obj->$attribute() eq $what )
            {
                return $obj;
            }

            #if ( $obj->has_attribute($attribute) ) {
            #    my $match_attr = $obj->$attribute();
            #    if ( ref $match_attr && $match_attr->name eq $what ) {
            #        warn "Woot! $obj";
            #        return $obj;
            #    }
            #    elsif ( $match_attr eq $what ) {
            #        return $obj;
            #    }
            #}
            #return $obj if ( $obj->name eq $what );
        }
    }
}

=item resolve()

Resolve the template for the specified object.  Templates will not work until this has been done.

 $parser->resolve( $object );

=cut

sub resolve {
    my ( $self, $object ) = @_;

    # return if this object has already been resolved
    return 1 if ( $object->resolved );

    # set the resolved flag
    $object->resolved(1);

    if (   exists $object->{use}
        && defined $object->{use}
        && !exists $object->{_use} )
    {
        my $template = $self->find_object( $object->use, ref $object );
        $object->{_use} = $template;
    }

    1;
}

=item register()

Examine all attributes of an object and link all of it's references to other Nagios objects to their respective perl objects.  If this isn't called, some methods will return the textual name instead of a perl object.

 $parser->register( $host_object );
 my $timeperiod_object = $host_object->notification_period;

=cut

sub register {
    my ( $self, $object ) = @_;

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

        next unless defined $object->$attribute();

        my $attr_type = $object->attribute_type($attribute);

        # all done unless the attribute is supposed to point to another object
        next unless $attr_type =~ /^Nagios::.*$/ or ref $attr_type eq 'ARRAY';

        # deal with lists types
        if ( !ref $attr_type && $object->attribute_is_list($attribute) ) {

            # pushed out to subroutine to keep things readable
            my @refs = $self->register_object_list( $object, $attribute,
                $attr_type );
            $object->_set( $attribute, \@refs );

        }

        # multi-type lists, like Nagios::ServiceGroup
        elsif ( ref $attr_type eq 'ARRAY' ) {
            my $values = $object->$attribute();
            confess "invalid element in attribute \"$attribute\" ($values)"
                unless ref($values) eq 'ARRAY';

            my @new_list;
            foreach my $value (@$values) {
                my @mapped;
                for ( my $i = 0; $i < @$attr_type; $i++ ) {
                    push @mapped,
                        $self->find_object( $value->[$i], $attr_type->[$i] );
                }
                push @new_list, \@mapped;
            }

            my $set = 'set_' . $attribute;
            $object->$set(@new_list);
        }
        else {
            my @refl = $self->find_objects( $object->$attribute(), $attr_type );
            if ( scalar @refl == 1 ) {
                $object->_set( $attribute, $refl[0] );
            }

            # If we have found multiple hits, then we most likely have a Nagios::Service
            # Need to pick the correct one.  Use the Nagios::Host object to help pick it.
            elsif ( scalar @refl > 1 && ( $object->can('host_name') || $object->can('hostgroup_name') ))  {
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
                    my $self = shift;
                    my $obj = $self->{'object_config_object'};
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
                my @h1 = &get_host_list($object);
                my $old_found = 0;
                foreach my $o ( @refl ) {
                    my @h2 = &get_host_list($o);
                    next if ( ! scalar @h2 );
                    my $found = 0;
                    foreach my $h ( @h1 ) {
                        $found++ if ( grep {$h eq $_} @h2 );
                    }
                    # Use the service which had the max hosts found.
                    if ( $found > $old_found ) {
                        $object->_set( $attribute, $o );
                        $old_found = $found;
                    }
                }
            }
        }

        # This field is marked as to be synced with it's group members object
        if ( ( $nagios_setup{ $object->setup_key }->{ $attribute }[1] & NAGIOS_GROUP_SYNC ) == NAGIOS_GROUP_SYNC ) {
            my $method = ( $attribute eq 'members'
                ? lc($object->{'_nagios_setup_key'}) . 's'
                : 'members');
            my $setmethod = 'set_' . $method;

            foreach my $o ( @{$object->$attribute()} ) {
                next if ( ! $o->can($method) );
                my $members = $o->$method();

                # If the object has not yet been registered, just add the name
                if ( ! $o->registered ) { 
                    if ( defined $members && ref $members eq '' ) {
                        $members = [ $members, $object->name ];
                    } else {
                        push @$members, $object->name;
                    }
                    $o->$setmethod($members);
                }

                # otherwise add the object itself.
                elsif ( ! $members || ! grep ({$object eq $_} @$members )) {
                    push @$members, $object;
                    $o->$setmethod($members);
                }
            }
        }
    }

    $object->registered(1);
}

sub register_object_list {
    my ( $self, $object, $attribute, $attr_type ) = @_;

# split on comma surrounded by whitespace or by just whitespace
#  - don't try splitting it if it has already been split by the Nagios::Object::_set function!
#  - same bug reported in CPAN's RT:  http://rt.cpan.org/Public/Bug/Display.html?id=31291
    my @to_find;
    my $value = $object->$attribute();
    if ( ref $value eq 'ARRAY' ) {
        @to_find = @{$value};
    }
    else {
        @to_find = split /\s*,\s*|\s+/, $value;
    }
    my @found = ();

    # handle splat '*' matching of all objects of a type (optimization)
    if ( @to_find == 1 && $to_find[0] eq '*' ) {
        @found = @{ $self->all_objects_for_type($attr_type); };
        confess
            "Wildcard matching failed.  Have you defined any $attr_type objects?"
            unless ( @found > 0 );
        return @found;
    }

    # now back to our regularly scheduled search ...

    my %wildcard_finds = ();

    foreach my $item (@to_find) {

    # no regular expression matching if both flags are false OR
    # only "regexp_matching" is enabled and the string does not contain ? or *
        if ((      !$self->{_regexp_matching_enabled}
                && !$self->{_true_regexp_matching_enabled}
            )
            || (  !$self->{_true_regexp_matching_enabled}
                && $item !~ /[\*\?]/ )
            )
        {
            my $ref = $self->find_object( $item, $attr_type );
            push( @found, $ref ) if ($ref);
        }

        # otherwise, use RE's (I bet most people have this turned on)
        else {
            my $re = $item;
            $re =~ s/(<=\.)\*/.*?/g;    # convert "*" to ".*?"
            $re =~ s/\?/./g;            # convert "?" to "."
                 # when true_regexp... isn't on, the RE is anchored
            if ( !$self->{_true_regexp_matching_enabled} ) {
                $re = "^$re\$";    # anchor the RE for Nagios "light" RE's
            }

            my @ret = $self->find_objects_by_regex( $re, $attr_type );

            croak
                "Wildcard match failed.   The generated regular expression was '$re'.  Maybe you meant to enable_true_regexp_matching?"
                unless @ret > 0;

            push @found, @ret;
        }
    }
    return @found;
}

=item resolve_objects()

Resolve all objects currently loaded into memory.  This can be called any number of times without corruption.

 $parser->resolve_objects();

=cut

sub resolve_objects {
    my $self = shift;

    foreach my $obj_type ( map { lc $_ } keys %nagios_setup ) {
        foreach my $object ( @{ $self->{ $obj_type . '_list' } } ) {
            $self->resolve($object);
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

    # Order we process the Object is important.  We need the Host/HostGroups
    # processed before the Service and the Service before the ServiceEescalation
    foreach my $obj_type ( map { lc $_ } sort keys %nagios_setup ) {
        foreach my $object ( @{ $self->{ $obj_type . '_list' } } ) {
            $self->register($object);
        }
    }

    $Nagios::Object::pre_link = undef;
    return 1;
}

=item enable_regexp_matching()/disable_regexp_matching()

This correlates to the "use_regexp_matching" option in nagios.cfg.
When this option is enabled, Nagios::Object::Config will translate "*" to ".*?" and "?" to "." and
evaluate the result as a perl RE, anchored at both ends for any value that can point to multiple
other objects (^ and $ are added to either end).

 $parser->enable_regexp_matching;
 $parser->disable_regexp_matching;

=cut

sub enable_regexp_matching  { shift->{_regexp_matching_enabled} = 1 }
sub disable_regexp_matching { shift->{_regexp_matching_enabled} = undef }

=item enable_true_regexp_matching()/disable_true_regexp_matching()

This correlates to the "use_true_regexp_matching" option in nagios.cfg.   This is very similar to
the enable_regexp_matching() option, but matches more data and allows more powerful RE syntax.
These modules will allow you the full power of perl RE's - this is probably more than is available
in Nagios, so don't blame me if something works here but not in Nagios (it's usually the other way
around anyways).

The generated RE's have the same translation as above, but do not have the anchors to ^ and $.

This option always supercedes enable_regexp_matching.

 $parser->enable_true_regexp_matching;
 $parser->disable_true_regexp_matching;

=cut

sub enable_true_regexp_matching { shift->{_true_regexp_matching_enabled} = 1 }

sub disable_true_regexp_matching {
    shift->{_true_regexp_matching_enabled} = undef;
}

=item list_hosts(), list_hostgroups(), etc.

Returns an array/arrayref of objects of the given type.

 $config->list_hosts
 $config->list_hostgroups
 $config->list_services
 $config->list_timeperiods
 $config->list_commands
 $config->list_contacts
 $config->list_contactgroups
 $config->list_hostdependencies
 $config->list_servicedependencies
 $config->list_hostescalations
 $config->list_hostgroupescalations
 $config->list_serviceescalations
 $config->list_servicegroups
 $config->list_hostextinfo
 $config->list_serviceextinfo

=cut

# may want to change this eventually to return a copy of the array
# instead of the array referenced in $self
sub _list {
    my ( $self, $type ) = @_;
    my $key = $type . '_list';
    wantarray ? @{ $self->{$key} } : $self->{$key};
}

sub list_hosts                { shift->_list('host') }
sub list_hostgroups           { shift->_list('hostgroup') }
sub list_services             { shift->_list('service') }
sub list_timeperiods          { shift->_list('timeperiod') }
sub list_commands             { shift->_list('command') }
sub list_contacts             { shift->_list('contact') }
sub list_contactgroups        { shift->_list('contactgroup') }
sub list_hostdependencies     { shift->_list('hostdependency') }
sub list_servicedependencies  { shift->_list('servicedependency') }
sub list_hostescalations      { shift->_list('hostescalation') }
sub list_hostgroupescalations { shift->_list('hostgroupescalation') }
sub list_serviceescalations   { shift->_list('serviceescalation') }
sub list_servicegroups        { shift->_list('servicegroup') }
sub list_hostextinfo          { shift->_list('hostextinfo') }
sub list_serviceextinfo       { shift->_list('serviceextinfo') }

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
            foreach my $h ( @{ $s->host_name } ) {
                if ( $h->host_name eq $self->host_name ) {
                    push( @retval, $s );
                }
            }
        }
        if ( $s->hostgroup_name ) {
            foreach my $hg ( @{ $s->hostgroup_name } ) {
                foreach my $h ( @{ $hg->members } ) {
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
sub Nagios::Host::snmp_community     { }
sub Nagios::Host::set_snmp_community { }

=back

=head1 AUTHOR

Al Tobey <tobeya@cpan.org>
Contributions From:
    Lynne Lawrence (API & bugs)

=cut

1;

