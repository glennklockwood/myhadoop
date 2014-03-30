#!/usr/bin/env bash
################################################################################
# myspark-configure.sh - the bare minimum script needed to configure Apache 
#   Spark after calling myhadoop-configure.sh to configure HDFS.  
#
# TODO:
#  * all sanity checks, e.g., ensure that myhadoop-configure has been set 
#    already before running this
#
# Glenn K. Lockwood, San Diego Supercomputer Center                 March 2014
################################################################################

### Current default behavior: dump spark configuration into $HADOOP_CONF_DIR.
### This is safe enough, as Spark does not share common config filenames.
SPARK_CONF_DIR=$HADOOP_CONF_DIR

### We are the master
MASTER=$(sed -e 's/\([^.]*\).*$/\1.ibnet0/' <<< $HOSTNAME)

### TODO: should validate $SPARK_HOME and use any existing configuration files
### there as starting points.  A non-issue in Spark 0.9.0, as it does not ship
### with any default configuration (only inactive templates)

### Fill up spark-env.sh
cat <<EOF >> $SPARK_CONF_DIR/spark-env.sh
export SPARK_MASTER_IP=$MASTER
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_DIR=/scratch/$USER/$PBS_JOBID
export SPARK_LOCAL_IP=\$(sed -e 's/\([^.]*\).*$/\1.ibnet0/' <<< \$HOSTNAME)
export SPARK_CONF_DIR=$SPARK_CONF_DIR
EOF

cat <<EOF 
Now you will want to
  export SPARK_SLAVES=$SPARK_CONF_DIR/slaves # is this necessary?  double check
  source $SPARK_CONF_DIR/spark-env.sh # definitely necessary
  $HADOOP_HOME/bin/start-dfs.sh # necessary (HDFS)
  $SPARK_HOME/sbin/start-all.sh # start up the spark workers
EOF
