###########################################################################
#                                                                         #
# Nagios::Config                                                          #
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
package Nagios::Config;
use warnings;
use strict qw( subs vars );
use Carp;
use Nagios::Object::Config;
use Nagios::Config::File;
use Nagios::Object qw(%nagios_setup);
use Symbol qw(gensym);
use File::Basename;
@Nagios::Config::ISA = qw( Nagios::Object::Config Nagios::Config::File );

# NOTE: due to CPAN version checks this cannot currently be changed to a
# standard version string, i.e. '0.21'
our $VERSION   = '36';
our $fast_mode = undef;

=head1 NAME

Nagios::Config - Parser for the Nagios::Object set of perl modules

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

 my $cf = Nagios::Config->new( Filename => $configfile );
 my $cf = Nagios::Config->new( Filename => $configfile, Version => 1 );
 my $cf = Nagios::Config->new( Filename => $configfile, Version => 2 );

=cut

sub new {
    my $class                = ref( $_[0] ) ? ref(shift) : shift;
    my $filename             = undef;
    my $version              = undef;
    my $allow_missing_files  = undef;
    my $force_relative_files = undef;

    if ( @_ % 2 == 0 ) {
        my %args = ();
        for ( my $i = 0; $i <= @_ && defined $_[$i]; $i += 2 ) {
            $args{ lc $_[$i] } = $_[ $i + 1 ];
        }
        if ( $args{filename} ) {
            $filename = $args{filename};
        }
        if ( $args{version} ) {
            $version = $args{version};
        }
        if ( $args{allow_missing_files} ) {
            $allow_missing_files = 1;
        }
        if ( $args{force_relative_files} ) {
            $force_relative_files = 1;
        }
    }
    else {
        croak "single argument form of new() no longer supported\n",
            "try Nagios::Config->new( Filename => \$file );";
    }

    my $main_cfg = Nagios::Config::File->new($filename);
    my $obj_cfgs = Nagios::Object::Config->new( Version => $version );

    # parse all object configuration files
    if ( my $files = $main_cfg->get('cfg_file') ) {
        foreach my $file (@$files) {
            if ($force_relative_files) {
                $file = _modpath( $filename, $file );
            }
            next if ( $allow_missing_files && !-e $file );
            $obj_cfgs->parse($file);
        }
    }

    # parse all files in cfg_dir(s)
    if ( my $dir = $main_cfg->get('cfg_dir') ) {
        my @dir_files = ();
        foreach my $cfgdir (@$dir) {
            recurse_dir( \@dir_files, $cfgdir );
        }
        foreach my $file (@dir_files) {
            if ($force_relative_files) {
                $file = _modpath( $filename, $file );
            }
            next if ( $allow_missing_files && !-e $file );
            $obj_cfgs->parse($file);
        }
    }

    # set up the important parts of the Nagios::Config::File instance
    $obj_cfgs->{filename}        = $filename;
    $obj_cfgs->{file_attributes} = $main_cfg->{file_attributes};

    # resolve and register Nagios::Object tree
    if ( !$fast_mode ) {
        $obj_cfgs->resolve_objects();
        $obj_cfgs->register_objects();
    }
    else {
        warn "EXPERIMENTAL: possible breakage with fast_mode enabled";
    }

    return bless $obj_cfgs, $class;
}

sub recurse_dir {
    my ( $file_list, $dir ) = @_;
    my $fh = gensym;
    opendir( $fh, $dir );
    while ( my $file = readdir $fh ) {
        if ( !-d "$dir/$file" && $file =~ /\.cfg$/ ) {
            push( @$file_list, "$dir/$file" );
        }
        elsif ( -d "$dir/$file" && $file !~ /^\./ && $file ne 'CVS' ) {
            recurse_dir( $file_list, "$dir/$file" );
        }
    }
}

sub _modpath {
    my ( $main_cfg, $sub_cfg ) = @_;
    my $cfgfile = File::Basename::basename($sub_cfg);
    my $subdir  = File::Basename::dirname($main_cfg);
    return $subdir . '/' . $cfgfile;
}

sub fast_mode {
    if ( $_[1] ) { $fast_mode = $_[1] }
    $Nagios::Object::fast_mode         = $fast_mode;
    $Nagios::Object::Config::fast_mode = $fast_mode;
    return $fast_mode;
}

1;

__END__

=back

=head1 AUTHOR

Al Tobey <tobeya@cpan.org>

=head1 SEE ALSO

Nagios::Config::File, Nagios::Object::Config, Nagios::Object

=cut

