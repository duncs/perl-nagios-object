#!/usr/local/bin/perl

use strict;
use warnings;
use Test::More tests => 9;
use Test::NoWarnings;
use File::Temp;
use lib qw( ../lib ./lib );

use_ok('Nagios::Object::Config');

my $cfg_file = File::Temp->new( UNLINK => 0, );

# NOTE: there are spaces and tabs in the following section
print $cfg_file <<'EOF';
define command {
    command_name    long-command
    command_line    /usr/bin/longcommand \
        -options=many \
		-uses=continuation-lines
}
EOF

$cfg_file->close;

my $parser
    = Nagios::Object::Config->new( Version => 2, regexp_matching => 1 );

isa_ok( $parser, 'Nagios::Object::Config' );

ok( $parser->parse( $cfg_file->filename ), 'parse ran OK' );

my $cmds = $parser->list_commands;
ok( $cmds, 'non-null list_commands' );
is( ref($cmds),         'ARRAY', 'Got expected arrayref' );
is( scalar( @{$cmds} ), 1,       'Got correct array count' );

is( $cmds->[0]->command_name, 'long-command', 'command_name set correctly' );
is( $cmds->[0]->command_line,
    '/usr/bin/longcommand -options=many -uses=continuation-lines',
    'command_line set correctly'
);

unlink( $cfg_file->filename );
