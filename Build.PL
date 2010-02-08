#!/usr/local/bin/perl -w
use strict;
use Module::Build;

my $build = Module::Build->new(
    dist_name      => 'Nagios-Object',
    dist_version   => "0.21.9",
    dist_author    => 'Duncan Ferguson <duncs@cpan.org>',
    dist_abstract  => 'Nagios::Object - Nagios object configuration parsing.',
    license        => 'gpl',
    requires       => { perl => '5.6.1' },
    build_requires => {
        'Test::More'       => 0.01,
        'Test::Exception'  => 0.01,
        'Module::Build'    => 0.26,
        'Data::Dumper'     => 0.01,
        'Scalar::Util'     => 0.01,
        'Test::NoWarnings' => 0.08,
    }
);

$build->create_build_script();

