#!/bin/bash

# Set this to location of myHadoop 
export MY_HADOOP_HOME="/home/srkrishnan/Software/myHadoop"

# Set this to the location of the Hadoop installation
export HADOOP_HOME="/home/srkrishnan/Software/hadoop-0.20.2"

# Set this to the location you want to use for HDFS
# Note that this path should point to a LOCAL directory, and
# that the path should exist on all slave nodes
export HADOOP_DATA_DIR="/state/partition1/hadoop-$USER/data"

# Set this to the location where you want the Hadoop logfies
export HADOOP_LOG_DIR="/state/partition1/hadoop-$USER/log"

