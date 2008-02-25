package Nagios::Host;
use base qw( Nagios::Object Nagios::Object::Config );
our $VERSION = '0.20';

=pod

No documentation here yet.  This module may not even survive on it's own.
There is one method, list_services which will list all the services for a
host.  It's very slow though.

=cut

# really slow, brute force way of listing services
sub list_services {
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
# keep the parser from bombing. (Al Tobey)
sub snmp_community { }
sub set_snmp_community { }

1;

