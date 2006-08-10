###########################################################################
#                                                                         #
# Nagios::Config                                                          #
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
package Nagios::Config;
use warnings;
use strict qw( subs vars );
use Carp;
use Nagios::Object::Config;
use Nagios::Config::File;
use Symbol;      # for dump
use Tie::Handle; # for dump
@Nagios::Config::ISA = qw( Nagios::Object::Config Nagios::Config::File );

=head1 NAME

Nagios::Config

=head1 DESCRIPTION

Ties all of the Nagios::Object modules together, doing all the parsing and
background stuff so you don't have to.

All of the methods of Nagios::Object::Config and Nagios::Config::File are
inherited by this module.

=head1 SYNOPSIS

 my $nagios_cfg = Nagios::Config->new( "nagios.cfg" );

 my @host_objects = $nagios_cfg->list_hosts();

=head1 METHODS

=over 4

=item new()

Create a new Nagios::Config object, which will parse a Nagios main
configuration file and all of it's object configuration files.
The resource configuration file is not parsed - for that, use Nagios::Config::File.

=cut

sub new {
    my $class = ref($_[0]) ? ref(shift) : shift;
    my $filename = shift;

    my $main_cfg = Nagios::Config::File->new( $filename );
    my $obj_cfgs = Nagios::Object::Config->new();

    # parse all object configuration files
    for ( @{$main_cfg->get('cfg_file')} ) {
        $obj_cfgs->parse( $_ );
    }

    # set up the important parts of the Nagios::Config::File instance
    $obj_cfgs->{filename} = $filename;
    $obj_cfgs->{file_attributes} = $main_cfg->{file_attributes};

    # resolve and register Nagios::Object tree
    $obj_cfgs->resolve_objects();
    $obj_cfgs->register_objects();

    return bless $obj_cfgs, $class;
}

sub list_object_types {
    no warnings;
    warn "this method is experimental - email tobeya\@cpan.org if you think this is a good idea";
    @Nagios::Object::object_types;
}

sub list_nagios_object_types {
    no warnings;
    warn "this method is experimental - email tobeya\@cpan.org if you think this is a good idea";
    @Nagios::Object::Config::valid_object_types;
}

__END__

=back

=head1 AUTHOR

Al Tobey <tobeya@cpan.org>

=head1 SEE ALSO

Nagios::Config::File, Nagios::Object::Config, Nagios::Object

=cut
