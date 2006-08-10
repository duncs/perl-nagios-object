#!/usr/local/bin/perl -w
use strict;
use Module::Build;

my $build = Module::Build->new(
    dist_name => 'Nagios-Object',
    dist_version => "0.05",
    license => 'gpl',
    requires => {
        perl => '5.6.0'
    },
    build_requires => {
        'Test::More' => 0
    }
);

$build->create_build_script();

