#!/usr/bin/perl

# $Id$
# $LastChangedDate$
# $Rev$

use lib qw(./lib ../lib);

use Nagios::Object qw(:all);

=head1 NAME

decode_flags.pl - decode the flags in Nagios/Object.pm

=head1 DESCRIPTION

The flags in Nagios/Object.pm are currently encoded into a single integer
by setting its individual bits.    Usually, I'd just use individual flags
for each of them, but it was getting to be too many to manage.   This is
actually pretty easy to handle once you get used to it and very common
in C programming.

=head1 SYNOPSIS

 decode_flags.pl 42
 decode_flags.pl NAGIOS_V2 NO_INHERIT

=cut

if ( @ARGV == 0 || !$ARGV[0] || $ARGV eq '-h' || $ARGV eq '--help' ) {
    print STDERR "Usage:\n\t$0 42\n\t$0 PERL_ONLY V1\n";
    exit 1;
}
elsif ( $ARGV[0] =~ /[^\d]/ ) {
    my $flag = 0;
    foreach my $nf (@ARGV) {
        if ( $nf =~ /NO_INHERIT$/i ) { $flag = ( $flag | NAGIOS_NO_INHERIT ) }
        if ( $nf =~ /PERL_ONLY$/i )  { $flag = ( $flag | NAGIOS_PERL_ONLY ) }
        if ( $nf =~ /V1$/i )         { $flag = ( $flag | NAGIOS_V1 ) }
        if ( $nf =~ /V2$/i )         { $flag = ( $flag | NAGIOS_V2 ) }
        if ( $nf =~ /V3$/i )         { $flag = ( $flag | NAGIOS_V3 ) }
        if ( $nf =~ /V1_ONLY$/i )    { $flag = ( $flag | NAGIOS_V1_ONLY ) }
        if ( $nf =~ /V2_ONLY$/i )    { $flag = ( $flag | NAGIOS_V2_ONLY ) }
        if ( $nf =~ /V3_ONLY$/i )    { $flag = ( $flag | NAGIOS_V3_ONLY ) }
        if ( $nf =~ /NO_DISPLAY$/i ) { $flag = ( $flag | NAGIOS_NO_DISPLAY ) }
    }

    printf "Integer for flags '%s' is %d\n", join( ', ', @ARGV ), $flag;
}
else {
    my @flags = ();

    push( @flags, 'NO_INHERIT' )
        if ( ( $ARGV[0] & NAGIOS_NO_INHERIT ) == NAGIOS_NO_INHERIT );
    push( @flags, 'PERL_ONLY' )
        if ( ( $ARGV[0] & NAGIOS_PERL_ONLY ) == NAGIOS_PERL_ONLY );
    push( @flags, 'V1' ) if ( ( $ARGV[0] & NAGIOS_V1 ) == NAGIOS_V1 );
    push( @flags, 'V2' ) if ( ( $ARGV[0] & NAGIOS_V2 ) == NAGIOS_V2 );
    push( @flags, 'V3' ) if ( ( $ARGV[0] & NAGIOS_V3 ) == NAGIOS_V3 );
    push( @flags, 'V1_ONLY' )
        if ( ( $ARGV[0] & NAGIOS_V1_ONLY ) == NAGIOS_V1_ONLY );
    push( @flags, 'V2_ONLY' )
        if ( ( $ARGV[0] & NAGIOS_V2_ONLY ) == NAGIOS_V2_ONLY );
    push( @flags, 'V3_ONLY' )
        if ( ( $ARGV[0] & NAGIOS_V3_ONLY ) == NAGIOS_V3_ONLY );
    push( @flags, 'NO_DISPLAY' )
        if ( ( $ARGV[0] & NAGIOS_NO_DISPLAY ) == NAGIOS_NO_DISPLAY );

    printf "Flags in number %d are '%s'\n", $ARGV[0], join( ', ', @flags );
}

