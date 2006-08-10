#!/usr/local/bin/perl
use lib qw(. ../lib /home/tobeya/work/lib);

use Nagios::Object qw(:all);

if ( @ARGV == 0 || !$ARGV[0] || $ARGV eq '-h' || $ARGV eq '--help' ) {
    print STDERR "Usage:\n\t$0 42\n\t$0 PERL_ONLY V1\n";
    exit 1;
}
elsif ( $ARGV[0] =~ /[^\d]/ ) {
	my $flag = 0;
	foreach my $nf ( @ARGV ) {
	    if ( $nf =~ /NO_INHERIT$/i ) { $flag = ($flag | NAGIOS_NO_INHERIT) }
	    if ( $nf =~ /PERL_ONLY$/i )  { $flag = ($flag | NAGIOS_PERL_ONLY)  }
	    if ( $nf =~ /V1$/i )         { $flag = ($flag | NAGIOS_V1)         }
	    if ( $nf =~ /V2$/i )         { $flag = ($flag | NAGIOS_V2)         }
	    if ( $nf =~ /V1_ONLY$/i )    { $flag = ($flag | NAGIOS_V1_ONLY)    }
	    if ( $nf =~ /V2_ONLY$/i )    { $flag = ($flag | NAGIOS_V2_ONLY)    }
	    if ( $nf =~ /NO_DISPLAY$/i ) { $flag = ($flag | NAGIOS_NO_DISPLAY) }
	}

	printf "Integer for flags '%s' is %d\n", join(', ',@ARGV), $flag;
}
else {
    my @flags = ();

    push( @flags, 'NO_INHERIT' ) if ( ($ARGV[0] & NAGIOS_NO_INHERIT) == NAGIOS_NO_INHERIT );
    push( @flags, 'PERL_ONLY' )  if ( ($ARGV[0] & NAGIOS_PERL_ONLY) == NAGIOS_PERL_ONLY );
    push( @flags, 'V1' )         if ( ($ARGV[0] & NAGIOS_V1) == NAGIOS_V1 );
    push( @flags, 'V2' )         if ( ($ARGV[0] & NAGIOS_V2) == NAGIOS_V2 );
    push( @flags, 'V1_ONLY' )    if ( ($ARGV[0] & NAGIOS_V1_ONLY) == NAGIOS_V1_ONLY );
    push( @flags, 'V2_ONLY' )    if ( ($ARGV[0] & NAGIOS_V2_ONLY) == NAGIOS_V2_ONLY );
    push( @flags, 'NO_DISPLAY' ) if ( ($ARGV[0] & NAGIOS_NO_DISPLAY) == NAGIOS_NO_DISPLAY);

    printf "Flags in number %d are '%s'\n", $ARGV[0], join(', ', @flags);
}

