#!/bin/bash

function print_usage {
    echo "Usage: -n NODES -p -d BASE_DIR -c CONFIG_DIR -h"
    echo "       -n: Number of nodes requested for the Hadoop installation"
    echo "       -p: Whether the Hadoop installation should be persistent"
    echo "           If so, data directories will have to be linked to a"
    echo "           directory that is not local to enable persistence"
    echo "       -d: Base directory to persist HDFS state, to be used if"
    echo "           -p is set"
    echo "       -c: The directory to generate Hadoop configs in"
    echo "       -h: Print help"
}

# initialize arguments
NODES=""
PERSIST="false"
BASE_DIR=""
CONFIG_DIR=""

# parse arguments
args=`getopt n:pd:c:h $*`
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

        -d) shift;
	    BASE_DIR=$1
            shift;;

        -c) shift;
	    CONFIG_DIR=$1
            shift;;

        -p) shift;
	    PERSIST="true"
	    ;;

        -h) shift;
	    print_usage
	    exit 0
    esac
done

if [ "$NODES" != "" ]; then
    echo "Number of Hadoop nodes requested: $NODES"
else 
    echo "Required parameter not set - number of nodes (-n)"
    print_usage
    exit 1
fi

if [ "$CONFIG_DIR" != "" ]; then
    echo "Generation Hadoop configuration in directory: $CONFIG_DIR"
else 
    echo "Location of configuration directory not specified"
    print_usage
    exit 1
fi

if [ "$PERSIST" = "true" ]; then
    echo "Persisting HDFS state (-p)"
    if [ "$BASE_DIR" = "" ]; then
	echo "Base directory (-d) not set for persisting HDFS state"
	print_usage
	exit 1
    else
	echo "Using directory $BASE_DIR for persisting HDFS state"
    fi
else
    echo "Not persisting HDFS state"
fi

# get the number of nodes from PBS
if [ -e $PBS_NODEFILE ]; then
    PBS_NODES=`awk 'END { print NR }' $PBS_NODEFILE`
    echo "Received $PBS_NODES nodes from PBS"

    if [ "$NODES" != "$PBS_NODES" ]; then
	echo "Number of nodes received from PBS not the same as number of nodes requested by user"
	exit 1
    fi
else 
    echo "PBS_NODEFILE is unavailable"
    exit 1
fi

# create the config, data, and log directories
rm -rf $CONFIG_DIR
mkdir -p $CONFIG_DIR

# first copy over all default Hadoop configs
cp $HADOOP_HOME/conf/* $CONFIG_DIR

# pick the master node as the first node in the PBS_NODEFILE
MASTER_NODE=`awk 'NR==1{print;exit}' $PBS_NODEFILE`
echo "Master is: $MASTER_NODE"
echo $MASTER_NODE > $CONFIG_DIR/masters

# every node in the PBS_NODEFILE is a slave
cat $PBS_NODEFILE > $CONFIG_DIR/slaves

# update the hdfs and mapred configs
sed 's/<value>.*:/<value>'"$MASTER_NODE"':/g' $MY_HADOOP_HOME/etc/mapred-site.xml > $CONFIG_DIR/mapred-site.xml
sed 's/hdfs:\/\/.*:/hdfs:\/\/'"$MASTER_NODE"':/g' $MY_HADOOP_HOME/etc/core-site.xml > $CONFIG_DIR/core-site.xml
sed -i 's:HADOOP_DATA_DIR:'"$HADOOP_DATA_DIR"':g' $CONFIG_DIR/core-site.xml
cp $MY_HADOOP_HOME/etc/hdfs-site.xml $CONFIG_DIR/

# update the HADOOP log directory
echo "" >> $CONFIG_DIR/hadoop-env.sh
echo "# Overwrite location of the log directory" >> $CONFIG_DIR/hadoop-env.sh
echo "export HADOOP_LOG_DIR=$HADOOP_LOG_DIR" >> $CONFIG_DIR/hadoop-env.sh

# set the HADOOP_HEAPSIZE to 4GB 
# echo "" >> $CONFIG_DIR/hadoop-env.sh
# echo "# Set the HADOOP_HEAPSIZE to 4GB" >> $CONFIG_DIR/hadoop-env.sh
# echo "export HADOOP_HEAPSIZE=4096" >> $CONFIG_DIR/hadoop-env.sh

# JVM settings
# echo "" >> $CONFIG_DIR/hadoop-env.sh
# echo "# JVM settings for Hadoop" >> $CONFIG_DIR/hadoop-env.sh
# echo "export HADOOP_OPTS=\"-server -XX:+UseParallelGC -XX:ParallelGCThreads=4 -XX:+AggressiveHeap -XX:+HeapDumpOnOutOfMemoryError\"" >> $CONFIG_DIR/hadoop-env.sh

# create or link HADOOP_{DATA,LOG}_DIR on all slaves
for ((i=1; i<=$NODES; i++))
do
    node=`awk 'NR=='"$i"'{print;exit}' $PBS_NODEFILE`
    echo "Configuring node: $node"
    cmd="rm -rf $HADOOP_LOG_DIR; mkdir -p $HADOOP_LOG_DIR"
    echo $cmd
    ssh $node $cmd 
    if [ "$PERSIST" = "true" ]; then
	cmd="rm -rf $HADOOP_DATA_DIR; ln -s $BASE_DIR/$i $HADOOP_DATA_DIR"
	echo $cmd
	ssh $node $cmd
    else
	cmd="rm -rf $HADOOP_DATA_DIR; mkdir -p $HADOOP_DATA_DIR"
	echo $cmd
	ssh $node $cmd 
    fi
done
