#!/usr/bin/env perl
#
# cluster-topo.pl - resolves cluster topology for Hadoop based on the Rocks
#   node naming convention of name-X-Y where X is the rack and Y is the node
#
use strict;
use warnings;
while ( my $host = shift( @ARGV ) )
{

    # Everything defaults to rack 0
    my ($rack, $slot, $vm) = ( 0, 0, 0 );
    if ( $host =~ m/^.*-(\d+)-(\d+)-(\d+)$/ )
    {
        ($rack, $slot, $vm) = ($1, $2, $3);
    }
    elsif ( $host =~ m/^.*-(\d+)-(\d+)$/ )
    {
        ($rack, $slot) = ($1, $2);
    }
    printf( "/dc%d/rack%d ", 0, $rack );
}
