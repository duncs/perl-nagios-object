###########################################################################
#                                                                         #
# Nagios::StatusLog, Nagios::(Service|Host|Program)::Status               #
# Written by Albert Tobey <tobeya@cpan.org>                               #
# Copyright 2003-2007, Albert P Tobey                                     #
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
package Nagios::StatusLog;
use Carp;
use strict qw( subs vars );
use warnings;
use Symbol;

our $VERSION = '$Rev$';

# this is going to be rewritten to use AUTOLOAD + method caching in a future version
BEGIN {
    # first block of items is from Nagios v1, second is new stuff in Nagios v2
    my %_tags = (
        Service => [qw(
            host_name description status current_attempt state_type last_check next_check check_type checks_enabled accept_passive_service_checks event_handler_enabled last_state_change problem_has_been_acknowledged last_hard_state time_ok time_unknown time_warning time_critical last_notification current_notification_number notifications_enabled latency execution_time flap_detection_enabled is_flapping percent_state_change scheduled_downtime_depth failure_prediction_enabled process_performance_data obsess_over_service plugin_output
            service_description modified_attributes check_command event_handler has_been_checked should_be_scheduled check_execution_time check_latency current_state max_attempts last_hard_state_change last_time_ok last_time_warning last_time_unknown last_time_critical performance_data next_notification no_more_notifications active_checks_enabled passive_checks_enabled acknowledgement_type last_update 
        )],

        Host => [qw(
            host_name status last_check last_state_change problem_has_been_acknowledged time_up time_down time_unreachable last_notification current_notification_number notifications_enabled event_handler_enabled checks_enabled flap_detection_enabled is_flapping percent_state_change scheduled_downtime_depth failure_prediction_enabled process_performance_data plugin_output
            modified_attributes check_command event_handler has_been_checked should_be_scheduled check_execution_time check_latency current_state last_hard_state check_type performance_data next_check current_attempt max_attempts state_type last_hard_state_change last_time_up last_time_down last_time_unreachable next_notification no_more_notifications acknowledgement_type active_checks_enabled passive_checks_enabled obsess_over_host last_update
        )],

        Program => [qw(
            program_start nagios_pid daemon_mode last_command_check last_log_rotation enable_notifications execute_service_checks accept_passive_service_checks enable_event_handlers obsess_over_services enable_flap_detection enable_failure_prediction process_performance_data
            modified_host_attributes modified_service_attributes active_service_checks_enabled passive_service_checks_enabled active_host_checks_enabled passive_host_checks_enabled obsess_over_hosts check_service_freshness check_host_freshness global_host_event_handler global_service_event_handler
        )],
        Info => [qw( created version )]
    );

    GENESIS: {
        no warnings;
        # create the Nagios::*::Status packages at compile time
	    foreach my $key ( keys(%_tags) ) {
	        my $pkg = 'Nagios::'.$key.'::Status::';
	
	        # store the list of tags for this package to access later
	        do { ${"${pkg}tags"} = $_tags{$key} };

            # modify @ISA for each class
            my $isa = do { \@{"${pkg}ISA"} };
            push( @$isa, 'Nagios::StatusLog' );
	
	        foreach my $method ( @{$_tags{$key}} ) {
                # the manually implemented status method is described below
	            *{"$pkg$method"} = sub { $_[0]->{$method} }
                    unless $method eq 'status';
	        }
        }
    }
}

=head1 NAME

Nagios::StatusLog, Nagios::(Service|Host|Program)::Status

=head1 DESCRIPTION

Reads the Nagios status log and returns ::Status objects that can
be used to get status information about a host.   For Nagios version 2.x logs,
pass in the Version => 2.0 parameter to new().

 my $log = Nagios::StatusLog->new(
                Filename => "/var/opt/nagios/status.log",
                Version  => 1.0
           );
 $localhost = $log->host( "localhost" );
 print "status of localhost is now ",$localhost->status(),"\n";
 $log->update();
 print "status of localhost is now ",$localhost->status(),"\n";

 # for Nagios v2.0
 my $log = Nagios::StatusLog->new(
                Filename => "/var/opt/nagios/status.dat",
                Version  => 2.0
           );

=head1 METHODS

=over 4

=item new()

Create a new Nagios::StatusLog instance.  The object will
be initialized for you (using $self->update()).
 Nagios::StatusLog->new( "/var/opt/nagios/status.log" );

=cut

sub new {
    my $type = shift;
    my $logfile = $_[0] if ( @_ == 1 );
    my $version = 1;
    
    if ( @_ % 2 == 0 ) {
        my %args = @_;
        while ( my($param,$value) = each %args ) {
            if ( lc $param eq 'filename' ) {
                $logfile = $value;
            }
            elsif ( lc $param eq 'version' ) {
                $version = $value;
            }
        }
    }

    if ( !defined($logfile) || !-r $logfile ) {
        die "could not open $logfile for reading: $!";
    }

    my $self = bless( {
        LOGFILE => $logfile,
        VERSION => $version,
        INFO    => {},
        PROGRAM => {},
        HOST    => {},
        SERVICE => {}
    }, $type );

    $self->update();
    return $self;
}

=item update()

Updates the internal data structures from the logfile.
 $log->update();

=cut

sub update {
    my $self = shift;
    if ( $self->{VERSION} >= 2 ) {
        return $self->update_v2( @_ );
    }
    return $self->update_v1( @_ );
}

sub update_v1 ($) {
    my $self = shift;

    # break the line down into a hash, return a reference
    sub hashline ($ $ $) {
        my( $line, $no, $ar ) = @_;
        my @parts = split(/;/, $$line, $no+1);
        # create the hash using the constant array (defined at top
        # of this file) and the split line
        my %data = map { $ar->[$_] => $parts[$_] } 0..$no;
        return \%data;
    }

    my $log_fh = gensym;
    open( $log_fh, "<$self->{LOGFILE}" )
        || croak "could not open file $self->{LOGFILE} for reading: $!";
    my @LOG = <$log_fh>;
    close( $log_fh );

    for ( my $i=0; $i<@LOG; $i++ ) {
        chomp( $LOG[$i] );
        $LOG[$i] =~ s/#.*$//;
        next if ( !defined($LOG[$i]) || !length($LOG[$i]) );
        $LOG[$i] =~ m/^(\[\d+])\s+([A-Z]+);(.*)$/;
        my( $ts, $type, $line ) = ( $1, $2, $3 );

        # set some variables to switch between SERVICES|HOST|PROGRAM
        # $no must be the number of elements - 1 (because arrays start on 0)

        my( $ldata, $ref ) = ( {}, undef );
        if ( $type eq 'SERVICE' ) {
            # let the hashline() function do the work of creating the hashref
            $ldata = hashline( \$line, 30, Nagios::Service::Status->list_tags() );

            # if it already exists, we'll copy data after this if/else tree
            if ( !exists($self->{$type}{$ldata->{host_name}}{$ldata->{description}}) ) {
                $self->{$type}{$ldata->{host_name}}{$ldata->{description}} = $ldata;
            }

            # 1st time we've seen this combination, use the new svc hashref
            else {
                $ref = $self->{$type}{$ldata->{host_name}}{$ldata->{description}};
            }
        }
        elsif ( $type eq 'HOST' ) {
            $ldata = hashline( \$line, 19, Nagios::Host::Status->list_tags() );
            if ( !exists($self->{$type}{$ldata->{host_name}}) ) {
                $self->{$type}{$ldata->{host_name}} = $ldata;
            }
            else {
                $ref = $self->{$type}{$ldata->{host_name}};
            }
        }
        elsif ( $type eq 'PROGRAM' ) {
            $ldata = hashline( \$line, 12, Nagios::Program::Status->list_tags() );
            if ( !defined($self->{$type}) ) {
                $self->{$type} = $ldata;
            }
            else {
                $ref = $self->{$type};
            }
        }
        else { croak "unknown tag ($type) in logfile"; }

        # update existing data without changing the location the reference points to
        if ( defined($ref) ) {
            foreach my $key ( keys(%$ldata) ) { $ref->{$key} = $ldata->{$key}; }
        }
    }
    1;
}

sub update_v2 ($) {
    my $self = shift;

    # be compatible with StatusLog which makes sure that references
    # held in client code remain valid during update (also prevents
    # some memory leaks)
    sub _copy {
        my( $from, $to ) = @_; 
        foreach my $key ( keys %$from ) {
            $to->{$key} = $from->{$key};
        }
    }

    my %handlers = (
        host => sub {
            my $item = shift;
            my $host = $item->{host_name};
            if ( !exists $self->{HOST}{$host} ) {
                $self->{HOST}{$host} = {};
            }
            _copy( $item, $self->{HOST}{$host} );
        },
        service => sub {
            my $item = shift;
            my $host = $item->{host_name};
            my $svc  = $item->{service_description};

            if ( !exists $self->{SERVICE}{$host}{$svc} ) {
                $self->{SERVICE}{$host}{$svc} = {};
            }
            _copy( $item, $self->{SERVICE}{$host}{$svc} );
        },
        info => sub {
            _copy( shift, $self->{INFO} );
        },
        program => sub { 
            _copy( shift, $self->{PROGRAM} );
        }

    );

    my $log_fh = gensym;
    open( $log_fh, "<$self->{LOGFILE}" )
        || croak "could not open file $self->{LOGFILE} for reading: $!";

    # change the first line of the RE to this:
    # (info|program|host|service) \s* {(
    # to make it a bit more careful, but it has a measurable cost on runtime
    my $entry_re = qr/
        # capture the type into $1
        (\w+) \s*
        # capture all of the text between the brackets into $2
        {( .*? )}
        # match the last bracket only if followed by another definition
        (?=(?: \s* (?:info|program|host|service) \s* { | \Z) )
        # capture remaining text (1-2 lines) into $3 for re-processing
        (.*)$
    /xs;

    my $entry = '';
    while ( my $line = <$log_fh> ) {
        next if ( $line =~ /^\s*#/ );
        $entry .= $line;
        if ( $entry =~ m/$entry_re/ ) {
            ( my $type, my $text, $entry ) = ( $1, $2, $3 );
            $text =~ s/[\r\n]+\s*/\n/g; # clean up whitespace and newlines
            my %item = map { split /\s*=\s*/, $_, 2 } split /\n/, $text;
            $handlers{$type}->( \%item );
        }
    }

    close( $log_fh );

    1;
}

sub list_tags {
    my $type = ref($_[0]) ? ref($_[0]) : $_[0];
    my $listref = ${"$type\::tags"};
    return wantarray ? @$listref : $listref;
}

=item service()

Returns a Nagios::Service::Status object.  Input arguments can be a host_name and description list, or a Nagios::Service object.
 my $svc_stat = $log->service( "localhost", "SSH" );
 my $svc_stat = $log->service( $localhost_ssh_svc_object );

Nagios::Service::Status has the following accessor methods (For V1):
 host_name
 description
 status 
 current_attempt
 state_type
 last_check next_check
 check_type
 checks_enabled
 accept_passive_service_checks
 event_handler_enabled
 last_state_change
 problem_has_been_acknowledged
 last_hard_state
 time_ok
 current_notification_number  
 time_warning
 time_critical
 process_performance_data
 notifications_enabled
 latency
 scheduled_downtime_depth 
 is_flapping
 plugin_output
 percent_state_change
 execution_time
 time_unknown
 failure_prediction_enabled
 last_notification
 obsess_over_service
 flap_detection_enabled 

=cut

sub service {
    my( $self, $host, $service ) = @_;

    if ( ref $host eq 'Nagios::Host' ) {
        $host = $host->host_name;
    }
    # allow just a service to be passed in
    if ( ref $host eq 'Nagios::Service' ) {
        $service = $host;
        $host = $service->host_name;
    }
    if ( ref $service eq 'Nagios::Service' ) {
        $service = $service->service_description;
    }

    confess "host \"$host\" does not seem to be valid"
        if ( !$self->{SERVICE}{$host} );
    confess "service \"$service\" does not seem to be valid on host \"$host\""
        if ( !$self->{SERVICE}{$host}{$service} );

    $self->{SERVICE}{$host}{$service}{__parent} = $self;
    bless( $self->{SERVICE}{$host}{$service}, 'Nagios::Service::Status' );
}

=item list_services()

Returns an array of all service descriptions in the status log.  Services that
may be listed on more than one host are only listed once here.

 my @all_services = $log->list_services;

=cut

sub list_services {
    my $self = shift;
    my %list = ();
    foreach my $host ( keys %{$self->{SERVICE}} ) {
        foreach my $service ( keys %{$self->{SERVICE}{$host}} ) {
            $list{$service} = 1;
        }
    }
    return keys %list;
}

=item list_services_on_host()

Returns an array of services descriptions for a given host.

 my @host_services = $log->list_services_on_host($hostname);
 my @host_services = $log->list_services_on_host($nagios_object);

=cut

sub list_services_on_host {
    my( $self, $host ) = @_;
    if ( ref $host && UNIVERSAL::can( $host, 'host_name') ) {
        $host = $host->host_name;
    }
    return keys %{$self->{SERVICE}{$host}};
}

=item host()

Returns a Nagios::Host::Status object.  Input can be a simple host_name, a Nagios::Host object, or a Nagios::Service object.
 my $hst_stat = $log->host( 'localhost' );
 my $hst_stat = $log->host( $host_object );
 my $hst_stat = $log->host( $svc_object );

Nagios::Host::Status has the following accessor methods (for V1):
 host_name
 status
 last_check
 last_state_change
 problem_has_been_acknowledged
 time_up
 time_down
 time_unreachable
 last_notification
 current_notification_number
 notifications_enabled
 event_handler_enabled
 checks_enabled
 flap_detection_enabled
 is_flapping
 percent_state_change
 scheduled_downtime_depth
 failure_prediction_enabled
 process_performance_data
 plugin_output

=cut

sub host {
    my( $self, $host ) = @_;

    if ( ref $host =~ /^Nagios::(Host|Service)$/ ) {
        $host = $host->host_name;
    }

    confess "host \"$host\" does not seem to be valid"
        if ( !$self->{HOST}{$host} );

    $self->{HOST}{$host}{__parent} = $self;
    bless( $self->{HOST}{$host}, 'Nagios::Host::Status' );
}

=item list_hosts()

Returns a simple array of host names (no objects).

 my @hosts = $log->list_hosts;

=cut

=item info() [Nagios v2 logs only]

Returns a Nagios::Info::Status object.   It only has two methods, created()
and version().

 my $i = $log->info;
 printf "Logfile created at %s unix epoch time for Nagios verion %s\n",
    $i->created,
    $i->version;

=cut

sub info {
    my $self = shift;
    return bless $self->{INFO}, 'Nagios::Info::Status';
}


sub list_hosts { keys %{$_[0]->{HOST}}; }

=item program()

Returns a Nagios::Program::Status object. No arguments.
 my $prog_st = $log->program;

Nagios::Program::Status has the following accessor methods (For V1):
 program_start
 nagios_pid
 daemon_mode
 last_command_check
 last_log_rotation
 enable_notifications
 execute_service_checks
 accept_passive_service_checks
 enable_event_handlers
 obsess_over_services
 enable_flap_detection
 enable_failure_prediction
 process_performance_data

=cut

sub program ($) { bless( $_[0]->{PROGRAM}, 'Nagios::Program::Status' ); }

sub write {
    my( $self, $filename ) = @_;
    my $ts = time;

    my $fh = gensym;
    open( $fh, ">$filename" )
        || die "could not open file \"$filename\" for writing: $!";

    print $fh, "[$ts] PROGRAM;", Nagios::Program::Status->csvline( $self->{PROGRAM} ), "\n";

    foreach my $host ( keys %{$self->{HOST}} ) {
        print $fh "[$ts] HOST;", Nagios::Host::Status->csvline( $self->{HOST}{$host} ), "\n";
    }
    foreach my $host ( keys %{$self->{SERVICE}} ) {
        foreach my $svc ( keys %{$self->{SERVICE}{$host}} ) {
            my $ref = $self->{SERVICE}{$host}{$svc};
            print $fh "[$ts] SERVICE;", Nagios::Service::Status->csvline( $ref ), "\n";
        }
    }

    close( $fh );
}

sub csvline {
    my $self = shift;
    my $data = shift || $self;
    join( ';', map { $data->{$_} } ($self->list_tags) ); 
}

=back

=head1 STRUCTURE

This module contains 4 packages: Nagios::StatusLog, Nagios::Host::Status,
Nagios::Service::Status, and Nagios::Program::Status.  The latter 3 of
them are mostly generated at compile-time in the BEGIN block.  The
accessor methods are real subroutines, not AUTOLOAD, so making a ton
of calls to this module should be fairly quick.  Also, update() is set
up to only do what it says - updating from a fresh logfile should not
invalidate your existing ::Status objects.

=head1 AUTHOR

Al Tobey <tobeya@tobert.org>

=head1 SEE ALSO

Nagios::Host Nagios::Service

=cut

package Nagios::Service::Status;

# Nagios 2.x has current_state instead of status, but since anybody
# using this module is probably using status and does not want to
# mess around with converting the integer, this method wraps it up
# to return like Nagios 1.x did.
sub status {
    my $self = shift;
    if ( $self->{__parent}{VERSION} > 1.9999999 ) {
        if ( $self->{current_state} == 0 ) {
            if ($self->{has_been_checked} == 0) {
                return 'PENDING';
            }
            else {
                return 'OK';
            }
        }
        elsif ( $self->{current_state} == 1 ) {
            return 'WARNING';
        }
        elsif ( $self->{current_state} == 2 ) {
            return 'CRITICAL';
        }
        elsif ( $self->{current_state} == 3 ) {
            return 'UNKNOWN';
        }
        else {
            return "Unknown Status '$self->{current_state}'";
        }
    }
    else {
        return $self->{status};
    }
}

package Nagios::Host::Status;

# same deal as Nagios::Service::Status::status()
sub status {
    my $self = shift;
    if ( $self->{__parent}{VERSION} > 1.9999999 ) {
        if ( $self->{current_state} == 0 ) {
            if ($self->{has_been_checked} == 0) {
                return 'PENDING';
            }
            else {
                return 'OK';
            }
        }
        elsif ( $self->{current_state} == 1 ) {
            return 'DOWN';
        }
        elsif ( $self->{current_state} == 2 ) {
            return 'UNREACHABLE';
        }
        else {
            return "Unknown Status '$self->{current_state}'";
        }
    }
    else {
        return $self->{status};
    }
}

package Nagios::Program::Status;

package Nagios::Info::Status;

1;

