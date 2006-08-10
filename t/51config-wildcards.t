use strict;
use Test::More qw(no_plan);
use lib qw( ./lib ../lib );
use Data::Dumper;
#BEGIN { plan tests => 7; }
eval { chdir('t') };

use_ok( 'Nagios::Object::Config' );

ok( my $cf = Nagios::Object::Config->new(
                Version => 2.0,
                true_regexp_matching => 1
             ),
    "Nagios::Object::Config->new()" );
$cf->parse( 'v2_wildcards.cfg' );  

ok( $cf->resolve_objects, "Run resolve_objects method." );
ok( $cf->register_objects, "Run register_objects method." );

ok( my @cgs = $cf->list_contactgroups, "List contact groups" );

is( scalar(@cgs), 1, "There should be only 1 contactgroup." );
my $cg = $cgs[0];

my $contacts = $cg->members;
is( scalar(@$contacts), 2, "Wildcard should have matched exactly two contacts." );

my @hgs = $cf->list_hostgroups;
my $printer_hg;
foreach ( @hgs ) {
    if ( $_->name eq 'printers' ) {
        $printer_hg = $_;
    }
}

my $printers = $printer_hg->members;
is( scalar(@$printers), 3, "\"prin\" should have matched all three printers." );

# add more tests ....

