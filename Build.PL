#!/usr/local/bin/perl -w
use strict;
use Module::Build;

my $build = Module::Build->new(
    dist_name => 'Nagios-Object',
    dist_version => "0.14",
    dist_author => 'Albert P Tobey <tobert@gmail.com>',
    dist_abstract => 'Nagios::Object - Nagios object configuration parsing.',
    license => 'gpl',
    requires => {
        perl => '5.6.0'
    },
    build_requires => {
        'Test::More' => 0.01,
        'Test::Exception' => 0.01
    }
);

$build->create_build_script();

