#!/usr/bin/perl -w

use strict;
use Test::More qw(no_plan);
use Scalar::Util qw(blessed);
use lib qw( ../lib ./lib );
use Data::Dumper;

#$Data::Dumper::Maxdepth = 2;
#$Data::Dumper::Deparse = 1;

eval { chdir('t') };

use Nagios::Config;

my $config = Nagios::Object::Config->new();
$config->parse( 'nestedtemplates.cfg' );

# this test verifies that the correct template name is being returned
foreach my $template ( $config->list_hosts ) {
    # get the names of the template and its parent for diagnostic output
    my $tname = $template->name;
    my $pname = $template->use || 'undefined';
    $pname = $pname->name if ( blessed $tname );
    my $message = "$pname isn't $tname (template name/object name)";

    # test!
    isnt( $template->use, $template->name, $message );
}

# now verify that object values are being returned properly with and
# without inheritance
# Note: these tests rely on the exact data in nestedtemplates.cfg

my $generic  = $config->find_object('generic-service', 'Nagios::Service');
my $perfdata = $config->find_object('perfdata-only',   'Nagios::Service');

isnt( $generic->name, $perfdata->name, "check template names" );
isnt( $generic->flap_detection_enabled, $perfdata->flap_detection_enabled,
      "check a value that should not be inherited" );
is( $perfdata->retry_check_interval, $generic->retry_check_interval,
      "check a value that should be inherited" );

#warn Dumper( $perfdata );

#warn $generic->dump;
#warn $perfdata->dump;

