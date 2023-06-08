package Nagios::Template;
use strict;
use warnings;
use Carp;

sub new {
    my $class = shift;
    return shift if @_ == 1;
    bless { objects => [ @_ ] }, $class
}

sub objects { @{shift->{objects}} }

sub can {
    my ($self,$meth) = @_;
    if (my $s = $self->SUPER::can($meth)) {
	return $s;
    }
    foreach my $obj ($self->objects) {
	if (defined($obj) && $obj->can($meth)) {
	    return $obj;
	}
    }
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s/(?:(.*)::)?(.+)//;
    my ($p, $m) = ($1, $2);
    my $has_attr;
    foreach my $obj ($self->objects) {
	if (defined($obj) && $obj->can($m)) {
	    $has_attr = 1;
	    if (defined(my $v = $obj->${\$m}(@_))) {
		return $v;
	    }
	}
    }
    return if $has_attr;
    croak "Can't locate object method \"$m\" via package \"$p\"";
}

sub DESTROY {}

1;

=head1 NAME
    
Nagios::Template - Perl object representing Nagios template

=head1 NOTE

Users of B<Nagios::Config> should never need to create objects of this
class.  It is used internally by B<Nagios::Object::Config> to implement
template inheritance.

=head1 DESCRIPTOION

The B<Nagios::Template> implements template inheritance.  The constructor
takes as its arguments the list of Nagios objects representing the right-
hand side of a "use" statement in Nagios configuration object.  If only
one object is given (simple inheritance), the constructor returns the
object transparently.  If given several arguments (multiple inheritance),
a new instance of B<Nagios::Template> is returned.

The set of attributes for an objects of this class is the union of attributes
supported by the objects supplied to its constructor.  When an attribute
is requested, the B<Nagios::Template> object iterates over its underlying
objects and returns the first value defined.  This conforms with the
behavior of Nagios as described in:

L<https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/objectinheritance.html>

=cut

