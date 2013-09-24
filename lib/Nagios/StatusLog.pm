###########################################################################
#                                                                         #
# Nagios::StatusLog, Nagios::(Service|Host|Program)::Status               #
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
package Nagios::StatusLog;
use Carp;
use strict qw( subs vars );
use warnings;
use Symbol;
use Scalar::Util;

# NOTE: due to CPAN version checks this cannot currently be changed to a
# standard version string, i.e. '0.21'
our $VERSION = '45';

# this is going to be rewritten to use AUTOLOAD + method caching in a future version
BEGIN {

    # first block of items is from Nagios v1, second is new stuff in Nagios v2
    my %_tags = (
        Service => [
            qw(
                host_name description status current_attempt state_type last_check next_check check_type checks_enabled accept_passive_service_checks event_handler_enabled last_state_change problem_has_been_acknowledged last_hard_state time_ok time_unknown time_warning time_critical last_notification current_notification_number notifications_enabled latency execution_time flap_detection_enabled is_flapping percent_state_change scheduled_downtime_depth failure_prediction_enabled process_performance_data obsess_over_service plugin_output
                service_description modified_attributes check_command event_handler has_been_checked should_be_scheduled check_execution_time check_latency current_state max_attempts last_hard_state_change last_time_ok last_time_warning last_time_unknown last_time_critical performance_data next_notification no_more_notifications active_checks_enabled passive_checks_enabled acknowledgement_type last_update
                check_interval check_options check_period current_event_id current_notification_id current_problem_id last_event_id last_problem_id long_plugin_output notification_period retry_interval
                )
        ],

        Host => [
            qw(
                host_name status last_check last_state_change problem_has_been_acknowledged time_up time_down time_unreachable last_notification current_notification_number notifications_enabled event_handler_enabled checks_enabled flap_detection_enabled is_flapping percent_state_change scheduled_downtime_depth failure_prediction_enabled process_performance_data plugin_output
                modified_attributes check_command event_handler has_been_checked should_be_scheduled check_execution_time check_latency current_state last_hard_state check_type performance_data next_check current_attempt max_attempts state_type last_hard_state_change last_time_up last_time_down last_time_unreachable next_notification no_more_notifications acknowledgement_type active_checks_enabled passive_checks_enabled obsess_over_host last_update
                check_interval check_options check_period current_event_id current_notification_id current_problem_id last_event_id last_problem_id long_plugin_output notification_period retry_interval
                )
        ],

        Program => [
            qw(
                program_start nagios_pid daemon_mode last_command_check last_log_rotation enable_notifications execute_service_checks accept_passive_service_checks enable_event_handlers obsess_over_services enable_flap_detection enable_failure_prediction process_performance_data
                modified_host_attributes modified_service_attributes active_service_checks_enabled passive_service_checks_enabled active_host_checks_enabled passive_host_checks_enabled obsess_over_hosts check_service_freshness check_host_freshness global_host_event_handler global_service_event_handler
                active_ondemand_host_check_stats active_ondemand_service_check_stats active_scheduled_host_check_stats active_scheduled_service_check_stats cached_host_check_stats cached_service_check_stats external_command_stats high_external_command_buffer_slots next_comment_id next_downtime_id next_event_id next_notification_id next_problem_id parallel_host_check_stats passive_host_check_stats passive_service_check_stats serial_host_check_stats total_external_command_buffer_slots used_external_command_buffer_slots
                )
        ],
        Contact => [
            qw(
                contact_name modified_attributes modified_host_attributes modified_service_attributes host_notification_period service_notification_period last_host_notification last_service_notification host_notifications_enabled service_notifications_enabled
                )
        ],
        Servicecomment => [
            qw(
                host_name service_description entry_type comment_id source persistent entry_time expires expire_time author comment_data
                )
        ],
        Hostcomment => [
            qw(
                host_name entry_type comment_id source persistent entry_time expires expire_time author comment_data
                )
        ],
        Servicedowntime => [
            qw(
                host_name service_description downtime_id entry_time start_time end_time triggered_by fixed duration author comment
                )
        ],
        Hostdowntime => [
            qw(
                host_name downtime_id entry_time start_time end_time triggered_by fixed duration author comment
                )
        ],
        Info => [qw( created version )]
    );

GENESIS: {
        no warnings;

        # create the Nagios::*::Status packages at compile time
        foreach my $key ( keys(%_tags) ) {
            my $pkg = 'Nagios::' . $key . '::Status::';

            # store the list of tags for this package to access later
            do { ${"${pkg}tags"} = $_tags{$key} };

            # modify @ISA for each class
            my $isa = do { \@{"${pkg}ISA"} };
            push( @$isa, 'Nagios::StatusLog' );

            foreach my $method ( @{ $_tags{$key} } ) {

                # the manually implemented status method is described below
                *{"$pkg$method"} = sub { $_[0]->{$method} }
                    unless $method eq 'status';
            }
        }
    }
}

=head1 NAME

Nagios::StatusLog, Nagios::(Service|Host|Program)::Status - Perl objects to represent the Nagios status file

=head1 DESCRIPTION

Reads the Nagios status log and returns ::Status objects that can
be used to get status information about a host.   For Nagios version 2.x logs,
pass in the Version => 2.0 parameter to new().  And similarly, pass in the
Version => 3.0 parameter to new() for Nagios version 3.x logs.

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

 # for Nagios v3.0
 my $log = Nagios::StatusLog->new(
                Filename => "/var/opt/nagios/status.dat",
                Version  => 3.0
           );

=head1 METHODS

=over 4

=item new()

Create a new Nagios::StatusLog instance.  The object will
be initialized for you (using $self->update()).
 Nagios::StatusLog->new( "/var/opt/nagios/status.log" );

=cut

sub new {
    my $type    = shift;
    my $logfile = $_[0] if ( @_ == 1 );
    my $version = 1;

    if ( @_ % 2 == 0 ) {
        my %args = @_;
        while ( my ( $param, $value ) = each %args ) {
            if ( lc $param eq 'filename' ) {
                $logfile = $value;
            }
            elsif ( lc $param eq 'version' ) {
                $version = int($value);
            }
        }
    }

    if ( !defined($logfile) || !-r $logfile ) {
        die "could not open $logfile for reading: $!";
    }

    my $self = bless(
        {   LOGFILE         => $logfile,
            VERSION         => $version,
            INFO            => {},
            CONTACT         => {},
            PROGRAM         => {},
            HOST            => {},
            HOSTCOMMENT     => {},
            HOSTDOWNTIME    => {},
            SERVICE         => {},
            SERVICECOMMENT  => {},
            SERVICEDOWNTIME => {}
        },
        $type
    );

    $self->update();
    return $self;
}

=item update()

Updates the internal data structures from the logfile.
 $log->update();

=cut

sub update {
    my $self = shift;
    if ( $self->{VERSION} >= 3 ) {
        return $self->update_v3(@_);
    }
    if ( $self->{VERSION} == 2 ) {
        return $self->update_v2(@_);
    }
    return $self->update_v1(@_);
}

sub update_v1 ($) {
    my $self = shift;

    # break the line down into a hash, return a reference
    sub hashline ($ $ $) {
        my ( $line, $no, $ar ) = @_;
        my @parts = split( /;/, $$line, $no + 1 );

        # create the hash using the constant array (defined at top
        # of this file) and the split line
        my %data = map { $ar->[$_] => $parts[$_] } 0 .. $no;
        return \%data;
    }

    my $log_fh = gensym;
    open( $log_fh, "<$self->{LOGFILE}" )
        || croak "could not open file $self->{LOGFILE} for reading: $!";
    my @LOG = <$log_fh>;
    close($log_fh);

    for ( my $i = 0; $i < @LOG; $i++ ) {
        chomp( $LOG[$i] );
        $LOG[$i] =~ s/#.*$//;
        next if ( !defined( $LOG[$i] ) || !length( $LOG[$i] ) );
        $LOG[$i] =~ m/^(\[\d+])\s+([A-Z]+);(.*)$/;
        my ( $ts, $type, $line ) = ( $1, $2, $3 );

        # set some variables to switch between SERVICES|HOST|PROGRAM
        # $no must be the number of elements - 1 (because arrays start on 0)

        my ( $ldata, $ref ) = ( {}, undef );
        if ( $type eq 'SERVICE' ) {

            # let the hashline() function do the work of creating the hashref
            $ldata = hashline( \$line, 30,
                Nagios::Service::Status->list_tags() );

            # if it already exists, we'll copy data after this if/else tree
            if (!exists(
                    $self->{$type}{ $ldata->{host_name} }
                        { $ldata->{description} }
                )
                )
            {
                $self->{$type}{ $ldata->{host_name} }{ $ldata->{description} }
                    = $ldata;
            }

            # 1st time we've seen this combination, use the new svc hashref
            else {
                $ref = $self->{$type}{ $ldata->{host_name} }
                    { $ldata->{description} };
            }
        }
        elsif ( $type eq 'HOST' ) {
            $ldata
                = hashline( \$line, 19, Nagios::Host::Status->list_tags() );
            if ( !exists( $self->{$type}{ $ldata->{host_name} } ) ) {
                $self->{$type}{ $ldata->{host_name} } = $ldata;
            }
            else {
                $ref = $self->{$type}{ $ldata->{host_name} };
            }
        }
        elsif ( $type eq 'PROGRAM' ) {
            $ldata = hashline( \$line, 12,
                Nagios::Program::Status->list_tags() );
            if ( !defined( $self->{$type} ) ) {
                $self->{$type} = $ldata;
            }
            else {
                $ref = $self->{$type};
            }
        }
        else { croak "unknown tag ($type) in logfile"; }

  # update existing data without changing the location the reference points to
        if ( defined($ref) ) {
            foreach my $key ( keys(%$ldata) ) {
                $ref->{$key} = $ldata->{$key};
            }
        }
    }
    1;
}

# be compatible with StatusLog which makes sure that references
# held in client code remain valid during update (also prevents
# some memory leaks)
sub _copy {
    %{ $_[1] } = %{ $_[0] };
}

sub update_v2 ($) {
    my $self = shift;

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
    /xs;

    my @lines = <$log_fh>;
    my $file  = "@lines";

#Drop comments if we don't need them as it should speed things up a little bit.
#Comment out the line below if you do want to keep comments
    $file =~ s/#.*\n//mg;
    $file =~ s/[\r\n]+\s*/\n/g;    # clean up whitespace and newlines

    while ( $file =~ /$entry_re/g ) {
        ( my $type, my $text ) = ( $1, $2 );
        my %item = map { split /\s*=\s*/, $_, 2 } split /\n/, $text;
        $handlers{$type}->( \%item );
    }

    close($log_fh);

    1;
}

sub update_v3 ($) {
    my $self = shift;

    my %handlers = (
        hoststatus => sub {
            my $item = shift;
            my $host = $item->{host_name};
            if ( !exists $self->{HOST}{$host} ) {
                $self->{HOST}{$host} = {};
            }
            _copy( $item, $self->{HOST}{$host} );
        },
        servicestatus => sub {
            my $item = shift;
            my $host = $item->{host_name};
            my $svc  = $item->{service_description};

            if ( !exists $self->{SERVICE}{$host}{$svc} ) {
                $self->{SERVICE}{$host}{$svc} = {};
            }
            _copy( $item, $self->{SERVICE}{$host}{$svc} );
        },
        contactstatus => sub {
            my $item    = shift;
            my $contact = $item->{contact_name};
            if ( !exists $self->{CONTACT}{$contact} ) {
                $self->{CONTACT}{$contact} = {};
            }
            _copy( $item, $self->{CONTACT}{$contact} );
        },
        info => sub {
            _copy( shift, $self->{INFO} );
        },
        programstatus => sub {
            _copy( shift, $self->{PROGRAM} );
        },

# Hosts & services can each have multiple comments & downtime, distinguished only by their Id:
        servicecomment => sub {
            my $item = shift;
            my $host = $item->{host_name};
            my $svc  = $item->{service_description};
            my $id   = $item->{comment_id};

            if ( !exists $self->{SERVICECOMMENT}{$host}{$svc}{$id} ) {
                $self->{SERVICECOMMENT}{$host}{$svc}{$id} = {};
            }
            _copy( $item, $self->{SERVICECOMMENT}{$host}{$svc}{$id} );
        },
        hostcomment => sub {
            my $item = shift;
            my $host = $item->{host_name};
            my $id   = $item->{comment_id};

            if ( !exists $self->{HOSTCOMMENT}{$host}{$id} ) {
                $self->{HOSTCOMMENT}{$host}{$id} = {};
            }
            _copy( $item, $self->{HOSTCOMMENT}{$host}{$id} );
        },
        servicedowntime => sub {
            my $item = shift;
            my $host = $item->{host_name};
            my $svc  = $item->{service_description};
            my $id   = $item->{downtime_id};

            if ( !exists $self->{SERVICEDOWNTIME}{$host}{$svc}{$id} ) {
                $self->{SERVICEDOWNTIME}{$host}{$svc}{$id} = {};
            }
            _copy( $item, $self->{SERVICEDOWNTIME}{$host}{$svc}{$id} );
        },
        hostdowntime => sub {
            my $item = shift;
            my $host = $item->{host_name};
            my $id   = $item->{downtime_id};

            if ( !exists $self->{HOSTDOWNTIME}{$host}{$id} ) {
                $self->{HOSTDOWNTIME}{$host}{$id} = {};
            }
            _copy( $item, $self->{HOSTDOWNTIME}{$host}{$id} );
        },

    );

    my $log_fh = gensym;
    open( $log_fh, "<$self->{LOGFILE}" )
        || croak "could not open file $self->{LOGFILE} for reading: $!";

    my %valid_types = map { ( $_ => 1 ) }
        qw(info programstatus hoststatus servicestatus contactstatus servicecomment hostcomment servicedowntime hostdowntime);
    my $entry = '';
    my %attributes;
    my $type = 0;
    while ( my $line = <$log_fh> ) {
        next if ( $line =~ /^\s*#|^\s*$/ );
        if ( $line =~ /\s*(\w+)=(.*)$/ ) {
            $attributes{$1} = $2;
        }
        elsif ( $line =~ /^\s*(\w+)\s*{\s*$/ ) {
            %attributes = ();
            if ( exists $valid_types{$1} ) {
                $type = $1;
            }
            else {
                $type = 0;
            }
        }
        elsif ( $line =~ /^\s*}\s*$/ ) {
            # Only save the object if it is a valid type
            if ($type) {
                $handlers{$type}->( \%attributes );
            }
        }
    }

    close($log_fh);

    1;
}

sub list_tags {
    my $type = ref( $_[0] ) ? ref( $_[0] ) : $_[0];
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
    my ( $self, $host, $service ) = @_;

    if ( ref($host) eq 'Nagios::Host' ) {
        $host = $host->host_name;
    }

    # allow just a service to be passed in
    if ( ref($host) eq 'Nagios::Service' ) {
        $service = $host;
        $host    = $service->host_name;
    }
    if ( ref($service) eq 'Nagios::Service' ) {
        $service = $service->service_description;
    }

    confess "host \"$host\" does not seem to be valid"
        if ( !$self->{SERVICE}{$host} );
    confess "service \"$service\" does not seem to be valid on host \"$host\""
        if ( !$self->{SERVICE}{$host}{$service} );

    $self->{SERVICE}{$host}{$service}{__parent} = $self;
    Scalar::Util::weaken($self->{SERVICE}{$host}{$service}{__parent});
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
    foreach my $host ( keys %{ $self->{SERVICE} } ) {
        foreach my $service ( keys %{ $self->{SERVICE}{$host} } ) {
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
    my ( $self, $host ) = @_;
    if ( ref($host) && UNIVERSAL::can( $host, 'host_name' ) ) {
        $host = $host->host_name;
    }
    return keys %{ $self->{SERVICE}{$host} };
}

=item serviceproblems()

Returns a hash of all services that are not in an OK state

 my %serviceproblems = $log->serviceproblems();

=cut

sub serviceproblems {
    my ( $self, $host, $service ) = @_;
    my %list = ();

    $self->{SERVICE}{$host}{$service}{__parent} = $self;
    Scalar::Util::weaken($self->{SERVICE}{$host}{$service}{__parent});
    
    foreach my $host ( keys %{ $self->{SERVICE} } ) {
        foreach my $service ( keys %{ $self->{SERVICE}{$host} } ) {
            $list{$host}{$service} = $self->{SERVICE}{$host}{$service} unless $self->{SERVICE}{$host}{$service}{current_state} == 0;
        }
    }
    return %list;
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
    my ( $self, $host ) = @_;

    if ( ref($host) =~ /^Nagios::(Host|Service)$/ ) {
        $host = $host->host_name;
    }

    confess "host \"$host\" does not seem to be valid"
        if ( !$self->{HOST}{$host} );

    $self->{HOST}{$host}{__parent} = $self;
    Scalar::Util::weaken($self->{HOST}{$host}{__parent});
    bless( $self->{HOST}{$host}, 'Nagios::Host::Status' );
}

=item list_hosts()

Returns a simple array of host names (no objects).

 my @hosts = $log->list_hosts;

=cut

sub list_hosts { keys %{ $_[0]->{HOST} }; }

=item list_hostdowntime()

Returns a simple array of host downtimes (no objects)

 my @hostdowntimes = $log->list_hostdowntime;

=cut

sub list_hostdowntime { keys %{ $_[0]->{HOSTDOWNTIME} }; }

=item info() [Nagios v2 & v3 logs only]

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

=item contact() [Nagios v3 logs only]

Returns a Nagios::Contact::Status object.  Input can be a simple contact_name, or a Nagios::Contact object.

 my $c = $log->contact( 'john' );
 my $c = $log->contact( $contact_object );

Nagios::Contact::Status has the following accessor methods (for v3):
 contact_name
 modified_attributes
 modified_host_attributes
 modified_service_attributes
 host_notification_period
 service_notification_period
 last_host_notification
 last_service_notification
 host_notifications_enabled
 service_notifications_enabled

=cut

sub contact {
    my ( $self, $name ) = @_;

    $name = $name->contact_name if ( ref($name) eq 'Nagios::Contact' );

    return undef if ( !$self->{CONTACT}{$name} );

    bless( $self->{CONTACT}{$name}, 'Nagios::Contact::Status' );
}

=item hostcomment() [Nagios v3 logs only]

Returns a Nagios::Hostcomment::Status object.  Input can be a simple host_name, or a Nagios::Host or Nagios::Service object.

 my $c = $log->hostcomment( 'localhost' );
 my $c = $log->hostcomment( $localhost_object );
 my $c = $log->hostcomment( $localhost_service_object );
 foreach my $id (sort keys %$c) {
     printf "Host %s has a comment[$id] made by %s on %s: %s",
       $c->{$id}->host_name, $c->{$id}->author, scalar localtime $c->{$id}->entry_time, $c->{$id}->comment_data;
 }

Nagios::Hostcomment::Status is a perl HASH, keyed with the Nagios comment IDs, where each ID has the following accessor methods (for v3):
 host_name
 entry_type
 comment_id
 source
 persistent
 entry_time
 expires
 expire_time
 author
 comment_data

=cut

sub hostcomment {
    my ( $self, $host ) = @_;

    $host = $host->host_name if ( ref($host) =~ /^Nagios::(Host|Service)$/ );

    return undef if ( !$self->{HOSTCOMMENT}{$host} );
    foreach my $id ( keys %{ $self->{HOSTCOMMENT}{$host} } ) {
        bless( $self->{HOSTCOMMENT}{$host}{$id},
            'Nagios::Hostcomment::Status' );
    }
    return $self->{HOSTCOMMENT}{$host};
}

=item servicecomment() [Nagios v3 logs only]

Returns a Nagios::Servicecomment::Status object.  Input can be a simple host_name or Nagios::Host object with
a service description or Nagios::Service object, or just a Nagios::Service object by itself.

 my $c = $log->servicecomment( 'localhost', 'SSH' );
 my $c = $log->servicecomment( $localhost_object, $localhost_ssh_svc_object );
 my $c = $log->servicecomment( $localhost_ssh_svc_object );
 foreach my $id (sort keys %$c) {
     printf "Service %s on %s  has a comment[$id] made by %s on %s: %s",
       $c->{$id}->service_description, $c->{$id}->host_name, $c->{$id}->author, scalar localtime $c->{$id}->entry_time, $c->{$id}->comment_data;
 }

Nagios::Servicecomment::Status is a perl HASH, keyed with the Nagios comment IDs, where each ID has the following accessor methods (for v3):
 host_name
 service_description
 entry_type
 comment_id
 source
 persistent
 entry_time
 expires
 expire_time
 author
 comment_data

=cut

sub servicecomment {
    my ( $self, $host, $service ) = @_;

    $host = $host->host_name if ( ref($host) eq 'Nagios::Host' );

    # allow just a service to be passed in
    if ( ref($host) eq 'Nagios::Service' ) {
        $service = $host;
        $host    = $service->host_name;
    }
    $service = $service->service_description
        if ( ref($service) eq 'Nagios::Service' );

    return undef
        if ( !$host
        || !$service
        || !$self->{SERVICECOMMENT}{$host}{$service} );
    foreach my $id ( keys %{ $self->{SERVICECOMMENT}{$host}{$service} } ) {
        bless( $self->{SERVICECOMMENT}{$host}{$service}{$id},
            'Nagios::Servicecomment::Status' );
    }
    return $self->{SERVICECOMMENT}{$host}{$service};
}

=item hostdowntime() [Nagios v3 logs only]

Returns a Nagios::Hostdowntime::Status object.  Input can be a simple host_name, or a Nagios::Host or Nagios::Service object.

 my $d = $log->hostdowntime( 'localhost' );
 my $d = $log->hostdowntime( $localhost_object );
 my $d = $log->hostdowntime( $localhost_service_object );
 foreach my $id (sort keys %$d) {
     printf "Host %s has scheduled downtime[$id] made by %s on %s for %.1f hours [%s - %s]: %s",
       $d->{$id}->host_name, $d->{$id}->author, scalar localtime $d->{$id}->entry_time, ($d->{$id}->duration)/3600.0,
         scalar localtime $d->{$id}->start_time, scalar localtime $d->{$id}->end_time, $d->{$id}->comment;
 }

Nagios::Hostdowntime::Status is a perl HASH, keyed with the Nagios downtime IDs, where each ID has the following accessor methods (for v3):
 host_name
 downtime_id
 entry_time
 start_time
 end_time
 triggered_by
 fixed
 duration
 author
 comment

=cut

sub hostdowntime {
    my ( $self, $host ) = @_;

    $host = $host->host_name if ( ref($host) =~ /^Nagios::(Host|Service)$/ );

    return undef if ( !$self->{HOSTDOWNTIME}{$host} );
    foreach my $id ( keys %{ $self->{HOSTDOWNTIME}{$host} } ) {
        bless(
            $self->{HOSTDOWNTIME}{$host}{$id},
            'Nagios::Hostdowntime::Status'
        );
    }
    return $self->{HOSTDOWNTIME}{$host};
}

=item servicedowntime() [Nagios v3 logs only]

Returns a Nagios::Servicedowntime::Status object.  Input can be a simple host_name or Nagios::Host object with
a service description or Nagios::Service object, or just a Nagios::Service object by itself.

 my $c = $log->servicedowntime( 'localhost', 'SSH' );
 my $c = $log->servicedowntime( $localhost_object, $localhost_ssh_svc_object );
 my $c = $log->servicedowntime( $localhost_ssh_svc_object );
 foreach my $id (sort keys %$d) {
     printf "Service %s on %s has scheduled downtime[$id] made by %s on %s for %.1f hours [%s - %s]: %s",
       $d->{$id}->service_description, $d->{$id}->host_name, $d->{$id}->author, scalar localtime $d->{$id}->entry_time, ($d->{$id}->duration)/3600.0,
         scalar localtime $d->{$id}->start_time, scalar localtime $d->{$id}->end_time, $d->{$id}->comment;
 }

Nagios::Servicedowntime::Status is a perl HASH, keyed with the Nagios downtime IDs, where each ID has the following accessor methods (for v3):
 host_name
 service_description
 downtime_id
 entry_time
 start_time
 end_time
 triggered_by
 fixed
 duration
 author
 comment

=cut

sub servicedowntime {
    my ( $self, $host, $service ) = @_;

    $host = $host->host_name if ( ref($host) eq 'Nagios::Host' );

    # allow just a service to be passed in
    if ( ref($host) eq 'Nagios::Service' ) {
        $service = $host;
        $host    = $service->host_name;
    }
    $service = $service->service_description
        if ( ref($service) eq 'Nagios::Service' );

    return undef if ( !$self->{SERVICEDOWNTIME}{$host}{$service} );
    foreach my $id ( keys %{ $self->{SERVICEDOWNTIME}{$host}{$service} } ) {
        bless( $self->{SERVICEDOWNTIME}{$host}{$service}{$id},
            'Nagios::Servicedowntime::Status' );
    }
    return $self->{SERVICEDOWNTIME}{$host}{$service};
}

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
    my ( $self, $filename ) = @_;
    my $ts = time;

    my $fh = gensym;
    open( $fh, ">$filename" )
        || die "could not open file \"$filename\" for writing: $!";

    print $fh, "[$ts] PROGRAM;",
        Nagios::Program::Status->csvline( $self->{PROGRAM} ), "\n";

    foreach my $host ( keys %{ $self->{HOST} } ) {
        print $fh "[$ts] HOST;",
            Nagios::Host::Status->csvline( $self->{HOST}{$host} ), "\n";
    }
    foreach my $host ( keys %{ $self->{SERVICE} } ) {
        foreach my $svc ( keys %{ $self->{SERVICE}{$host} } ) {
            my $ref = $self->{SERVICE}{$host}{$svc};
            print $fh "[$ts] SERVICE;",
                Nagios::Service::Status->csvline($ref), "\n";
        }
    }

    close($fh);
}

sub csvline {
    my $self = shift;
    my $data = shift || $self;
    join( ';', map { $data->{$_} } ( $self->list_tags ) );
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

our $VERSION = '0.1';

# Nagios 2.x has current_state instead of status, but since anybody
# using this module is probably using status and does not want to
# mess around with converting the integer, this method wraps it up
# to return like Nagios 1.x did.
sub status {
    my $self = shift;
    if ( $self->{__parent}{VERSION} > 1.9999999 ) {
        if ( $self->{current_state} == 0 ) {
            if ( $self->{has_been_checked} == 0 ) {
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
our $VERSION = '0.1';

# same deal as Nagios::Service::Status::status()
sub status {
    my $self = shift;
    if ( $self->{__parent}{VERSION} > 1.9999999 ) {
        if ( $self->{current_state} == 0 ) {
            if ( $self->{has_been_checked} == 0 ) {
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
our $VERSION = '0.1';

package Nagios::Info::Status;
our $VERSION = '0.1';

1;

