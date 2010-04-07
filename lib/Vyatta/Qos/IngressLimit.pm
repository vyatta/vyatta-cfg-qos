# Ingress traffic limit
#
# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2010 Vyatta, Inc.
# All Rights Reserved.
# **** End License ****

package Vyatta::Qos::IngressLimit;
use strict;
use warnings;

require Vyatta::Config;
require Vyatta::Qos::LimiterClass;


# Create a new instance based on config information
sub new {
    my ( $that, $config, $name ) = @_;
    my $self = {};
    my $class = ref($that) || $that;

    bless $self, $class;
    $self->_define($config);

    return $self;
}

# Setup new instance.
sub _define {
    my ( $self, $config ) = @_;
    my $level   = $config->setLevel();
    my @classes = ();

    $self->{_level} = $level;

    # make sure no clash of different types of tc filters
    my %matchTypes = ();
    foreach my $class ( $config->listNodes("class") ) {
        foreach my $match ( $config->listNodes("class $class match") ) {
            foreach my $type ( $config->listNodes("class $class match $match") ) {
		next if ($type eq 'description');
                $matchTypes{$type} = "$class match $match";
            }
        }
    }

    if ( scalar keys %matchTypes > 1 && $matchTypes{ip} ) {
        print "Match type conflict:\n";
        while ( my ( $type, $usage ) = each(%matchTypes) ) {
            print "   class $usage $type\n";
        }
        die "$level can not match on both ip and other types\n";
    }

    foreach my $id ( $config->listNodes("class") ) {
        $config->setLevel("$level class $id");
        push @classes, new Vyatta::Qos::LimiterClass( $config, $id );
    }
    $self->{_classes} = \@classes;
}

sub commands {
    my ( $self, $dev, $parent ) = @_;
    my $classes = $self->{_classes};

    foreach my $class (@$classes) {
        foreach my $match ( $class->matchRules() ) {
	    my $police = " police rate " . $class->{rate}
	    . " burst " . $class->{burst};

	    $match->filter( $dev, $parent, $class->{id}, $class->{priority},
			    undef, $police );
        }
    }
}

1;