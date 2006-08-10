#!/usr/bin/perl -w
use strict;
use Test::More qw(no_plan);
use lib qw( ../lib ./lib );
use Data::Dumper;

eval { chdir('t') };

use Nagios::Object::Config;

my $parser = Nagios::Object::Config->new();

$parser->parse( 'nestedtemplates.cfg' );

ok( $parser->resolve_objects, "\$parser->resolve_objects" );
ok( $parser->register_objects, "\$parser->register_objects" );

foreach my $template ( $parser->list_hosts ) {
    my $tname = $template->use->name if ( $template->use && $template->use->can('name') );
    my $message = sprintf "%s isn't %s (template name/object name)",
        $tname, $template->name;
    isnt( $template->use, $template->name, $message );
}
