###########################################################################
#                                                                         #
# Nagios::StatusLog, Nagios::(Service|Host|Program)::Status               #
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
package Nagios::StatusLog;
use Carp;
use strict qw( subs vars );
use warnings;

# for an explanation of what happens in this block, look at Nagios::Object
BEGIN {
    my %_tags = (
        Service => [qw(host_name description status current_attempt state_type last_check next_check check_type checks_enabled accept_passive_service_checks event_handler_enabled last_state_change problem_has_been_acknowledged last_hard_state time_ok time_unknown time_warning time_critical last_notification current_notification_number notifications_enabled latency execution_time flap_detection_enabled is_flapping percent_state_change scheduled_downtime_depth failure_prediction_enabled process_performance_data obsess_over_service plugin_output)],

        Host => [qw( host_name status last_check last_state_change problem_has_been_acknowledged time_up time_down time_unreachable last_notification current_notification_number notifications_enabled event_handler_enabled checks_enabled flap_detection_enabled is_flapping percent_state_change scheduled_downtime_depth failure_prediction_enabled process_performance_data plugin_output )],

        Program => [qw( program_start nagios_pid daemon_mode last_command_check last_log_rotation enable_notifications execute_service_checks accept_passive_service_checks enable_event_handlers obsess_over_services enable_flap_detection enable_failure_prediction process_performance_data )]
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
	            *{$pkg.$method} = sub { $_[0]->{$method} };
	        }
        }
    }
}

=head1 NAME

Nagios::StatusLog, Nagios::(Service|Host|Program)::Status

=head1 DESCRIPTION

Reads the Nagios status log and returns ::Status objects that can
be used to get status information about a host.

 my $log = Nagios::StatusLog->new( "/var/opt/nagios/status.log" );
 $localhost = $log->host( "localhost" );
 print "status of localhost is now ",$localhost->status(),"\n";
 $log->update();
 print "status of localhost is now ",$localhost->status(),"\n";

=head1 METHODS

=over 4

=item new()

Create a new Nagios::StatusLog instance.  The object will
be initialized for you (using $self->update()).
 Nagios::StatusLog->new( "/var/opt/nagios/status.log" );

=cut

sub new ($ $) {
    my( $type, $logfile ) = @_;
    if ( !defined($logfile) || !-r $logfile ) {
        die "could not open $logfile for reading: $!";
    }
    my $self = bless( [$logfile], $type );
    $self->update();
    return $self;
}

=item update()

Updates the internal data structures from the logfile.
 $log->update();

=cut

sub update ($) {
    my $self = shift;

    # break the line down into a hash, return a reference
    sub hashline ($ $ $) {
        my( $line, $no, $ar ) = @_;
        my @parts = split(/;/, $$line, $no+1);
        # create the hash using the constant array (defined at top
        # of this file) and the split line
        my %svc = map { $ar->[$_] => $parts[$_] } 0..$no;
        return \%svc;
    }

    open( LOG, "<$self->[0]" )
        || croak "could not open file $self->[0] for reading: $!";

    # shuffle old data to 4..6 and reinitialize 1..3
    # this would invalidate existing objects
    #for ( 1..3 ) { $self->[$_ + 3] = $self->[$_]; $self->[$_] = {}; }

    while ( my $line = <LOG> ) {
        chomp( $line );
        $line =~ s/#.*$//;
        next if ( !defined($line) || !length($line) );
        $line =~ s/^(\[\d+])\s+([A-Z]+);//;
        my( $ts, $type ) = ( $1, $2 );

        # set some variables to switch between SERVICES|HOST|PROGRAM
        # $no must be the number of elements - 1 (because arrays start on 0)

        my( $svc, $ref ) = ( {}, undef );
        if ( $type eq 'SERVICE' ) {
            # let the hashline() function do the work of creating the hashref
            $svc = hashline( \$line, 30, Nagios::Service::Status->list_tags() );

            # if it already exists, we'll copy data after this if/else tree
            if ( !exists($self->[1]{$svc->{host_name}}{$svc->{description}}) ) {
                $self->[1]{$svc->{host_name}}{$svc->{description}} = $svc;
            }

            # 1st time we've seen this combination, use the new svc hashref
            else {
                $ref = $self->[1]{$svc->{host_name}}{$svc->{description}};
            }
        }
        elsif ( $type eq 'HOST' ) {
            $svc = hashline( \$line, 19, Nagios::Host::Status->list_tags() );
            if ( !exists($self->[2]{$svc->{host_name}}) ) {
                $self->[2]{$svc->{host_name}} = $svc;
            }
            else {
                $ref = $self->[2]{$svc->{host_name}};
            }
        }
        elsif ( $type eq 'PROGRAM' ) {
            $svc = hashline( \$line, 12, Nagios::Program::Status->list_tags() );
            if ( !defined($self->[3]) ) {
                $self->[3] = $svc;
            }
            else {
                $ref = $self->[3];
            }
        }
        else { croak "unknown tag ($type) in logfile"; }

        # update existing data without changing the location the reference points to
        if ( defined($ref) ) {
            foreach my $key ( keys(%$svc) ) { $ref->{$key} = $svc->{$key}; }
        }
    }

    close( LOG );
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

Nagios::Service::Status has the following accessor methods:
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
        if ( !$self->[1]{$host} );
    confess "service \"$service\" does not seem to be valid on host \"$host\""
        if ( !$self->[1]{$host}{$service} );

    bless( $self->[1]{$host}{$service}, 'Nagios::Service::Status' );
}

=item host()

Returns a Nagios::Host::Status object.  Input can be a simple host_name, a Nagios::Host object, or a Nagios::Service object.
 my $hst_stat = $log->host( 'localhost' );
 my $hst_stat = $log->host( $host_object );
 my $hst_stat = $log->host( $svc_object );

Nagios::Host::Status has the following accessor methods:
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
        if ( !$self->[2]{$host} );

    bless( $self->[2]{$host}, 'Nagios::Host::Status' );
}

=item program()

Returns a Nagios::Program::Status object. No arguments.
 my $prog_st = $log->program();

Nagios::Program::Status has the following accessor methods:
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

sub program ($) { bless( $_[0]->[3], 'Nagios::Program::Status' ); }

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

1;
