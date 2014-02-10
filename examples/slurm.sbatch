#!/bin/bash
################################################################################
#  slurm.sbatch - A sample submit script for SLURM that illustrates how to
#    spin up a Hadoop cluster for a map/reduce task using myHadoop
#
#  Glenn K. Lockwood, San Diego Supercomputer Center             February 2014
################################################################################
#SBATCH -p development
#SBATCH -n 64
#SBATCH -t 1:00:00

### If these aren't already in your environment (e.g., .bashrc), you must define
### them.  We assume hadoop and myHadoop were installed in $HOME/hadoop-stack
export HADOOP_HOME=$HOME/hadoop-stack/hadoop-1.2.1
export PATH=$HADOOP_HOME/bin:$HOME/hadoop-stack/myhadoop/bin:$PATH:$PATH
export JAVA_HOME=/usr/java/latest

export HADOOP_CONF_DIR=$PWD/hadoop-conf.$SLURM_JOBID

myhadoop-configure.sh -c $HADOOP_CONF_DIR -s /tmp/$USER/$SLURM_JOBID

if [ ! -f ./pg2701.txt ]; then
  echo "*** Retrieving some sample input data"
  wget 'http://www.gutenberg.org/cache/epub/2701/pg2701.txt'
fi

$HADOOP_HOME/bin/start-all.sh

$HADOOP_HOME/bin/hadoop dfs -mkdir data
$HADOOP_HOME/bin/hadoop dfs -put ./pg2701.txt data/
$HADOOP_HOME/bin/hadoop dfs -ls data
$HADOOP_HOME/bin/hadoop jar $HADOOP_HOME/hadoop-examples-*.jar wordcount data wordcount-output
$HADOOP_HOME/bin/hadoop dfs -ls wordcount-output
$HADOOP_HOME/bin/hadoop dfs -get wordcount-output ./

$HADOOP_HOME/bin/stop-all.sh

myhadoop-cleanup.sh
