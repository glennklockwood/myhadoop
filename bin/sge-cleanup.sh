#!/bin/bash

function print_usage {
    echo "Usage: -n NODES -h"
    echo "       -n: Number of nodes requested for the Hadoop installation"
    echo "       -h: Print help"
}

# initialize arguments
NODES=""

# parse arguments
args=`getopt n:h $*`
if test $? != 0
then
    print_usage
    exit 1
fi
set -- $args
for i
do
    case "$i" in
        -n) shift;
	    NODES=$1
            shift;;

        -h) shift;
	    print_usage
	    exit 0
    esac
done

if [ "$NODES" != "" ]; then
    echo "Number of Hadoop nodes specified by user: $NODES"
else 
    echo "Required parameter not set - number of nodes (-n)"
    print_usage
    exit 1
fi

# get the number of nodes from SGE
if [ "$NODES" != "$NSLOTS" ]; then
    echo "Number of nodes received from SGE not the same as number of nodes requested by user"
    exit 1
fi

# clean up working directories for N-node Hadoop cluster
for ((i=1; i<=$NODES; i++))
do
    node=`awk 'NR=='"$i"'{print $1;exit}' $PE_HOSTFILE`
    echo "Clean up node: $node"
    cmd="rm -rf $HADOOP_DATA_DIR $HADOOP_LOG_DIR"
    echo $cmd
    ssh $node $cmd 
done
