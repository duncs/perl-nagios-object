package Nagios::Config::File;

use strict;
use warnings;
use Carp;
use Symbol;

# NOTE: due to CPAN version checks this cannot currently be changed to a
# standard version string, i.e. '0.21'
our $VERSION = '35';

my %DUPLICATES_ALLOWED = (
    cfg_file => 1,
    cfg_dir  => 1,
);

=head1 NAME

Nagios::Config::File - Base class for Nagios configuration files

=head1 SYNOPSIS

  use Nagios::Config ;
  my $nc = new Nagios::Config("/usr/local/nagios/etc/nagios.cfg") ;
  my $resource = $nc->get_resource_cfg() ; 
  print $resource->get_attr('$USER1$') . "\n" ;

=head1 DESCRIPTION

C<Nagios::Config::File> is the base class for all Nagios configuration
files. You should not need to create these yourself.

=cut

=head1 CONSTRUCTOR

=over 4

=item new ([FILE])

Creates a C<Nagios::Config::File>.

=back

=cut

sub new {
    my $class = shift;
    my $file  = shift;

    croak "Missing argument: must specify a configuration file to parse."
        if ( !$file );

    my $this = {};
    bless( $this, $class );

    my $fh = undef;
    if ( ref($file) ) {
        $fh = $file;
    }
    else {
        $fh = gensym;
        open( $fh, "<$file" )
            || croak("Can't open $file for reading: $!");
        $this->{filename} = $file;
    }

    $this->{file_attributes} = {};
    $this->{fh}              = $fh;

    $this->parse();
    close($fh);

    return $this;
}

sub parse {
    my $this = shift;

    my $fh = $this->{fh};

    while (<$fh>) {
        my $line = $this->strip($_);

        if ( $this->is_comment($line) ) {
            next;
        }
        elsif ( my ( $name, $value ) = $this->is_attribute($line) ) {
            if ( $DUPLICATES_ALLOWED{$name} ) {
                push @{ $this->{file_attributes}->{$name} }, $value;
            }
            else {
                $this->{file_attributes}->{$name} = $value;
            }
        }
    }
}

sub strip {
    my $this = shift;
    my $line = shift;

    $line =~ s/^\s+//;
    $line =~ s/\s+$//;

    return $line;
}

sub is_comment {
    my $this = shift;
    my $line = shift;

    if ( ( $line eq '' ) || ( $line =~ /^#/ ) ) {
        return 1;
    }

    return 0;
}

sub is_attribute {
    my $this = shift;
    my $line = shift;

    if ( $line =~ /^([\w\$]+)\s*=\s*(.+)$/ ) {
        return ( $1, $2 );
    }

    return ();
}

=head1 METHODS

=over 4

=item get ([NAME], [SPLIT])

Returns the value of the attribute C<NAME> for the current file.
If C<SPLIT> is true, returns a list of all the values split on
/\s*,\s*/. This is useful for attributes that can have more that one value.

=cut

sub get {
    my ( $this, $name, $split ) = @_;
    my $val = $this->{file_attributes}->{$name};
    return $split ? split( /\s*,\s*/, $val ) : $val;
}
sub get_attr { &get; }

=item filename()

Returns the filename for the current object.

=cut

sub filename { $_[0]->{filename} }

=item dump ()

Returns a scalar with the full configuration text ready to parse again.

=cut

sub dump {
    my $this   = shift;
    my $outtxt = "# filename: $this->{filename}\n";
    foreach my $attr ( keys( %{ $this->{file_attributes} } ) ) {
        if ( $DUPLICATES_ALLOWED{$attr} ) {
            foreach my $element ( @{ $this->{file_attributes}{$attr} } ) {
                $outtxt .= $attr . '=' . $element . "\n";
            }
        }
        else {
            $outtxt .= $attr . '=' . $this->{file_attributes}{$attr} . "\n";
        }
    }
    return $outtxt;
}

1;

=back 

=head1 AUTHOR

Patrick LeBoutillier, patl@cpan.org

Al Tobey, tobeya@cpan.org

=head1 SEE ALSO

Nagios::Config, Nagios::Config::Object

=cut

