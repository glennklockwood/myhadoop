#!/bin/bash
################################################################################
#
#  myhadoop-bootstrap - call from within a job script to do the entire cluster
#   setup in a hands-off fashion
#
#  Glenn K. Lockwood                                             January 2014
#
################################################################################

MY_HADOOP_HOME="/home/glock/src/myhadoop"
MY_HADOOP_IBOIB_SUFFIX=".ibnet0"
MY_HADOOP_IBOIB_PREFIX=""
MY_HADOOP_LIFETIME=$((6 * 3600))

### Cleanup script and signal trap
myhadoop-bootstrap-terminate() {
  $HADOOP_HOME/bin/stop-all.sh
  ### Copy back all log files in the event of job failure
  cp -Lr $HADOOP_LOG_DIR $MH_WORKDIR/hadoop-logs.$MH_JOBID
  $MY_HADOOP_HOME/bin/myhadoop-cleanup.sh -n $MH_NUM_NODES
  exit
}
trap myhadoop-bootstrap-terminate SIGHUP SIGINT SIGTERM

### Determine our resource manager
RESOURCE_MGR="undef"
if [ "z$PBS_O_WORKDIR" != "z" ]
then
    RESOURCE_MGR="pbs"
fi

### Extract the necessary environment variables
if [ "$RESOURCE_MGR" == "pbs" ]
then
    # PBS/Torque
    MH_WORKDIR=$PBS_O_WORKDIR
    MH_JOBID=$PBS_JOBID
    MH_NODEF=$PBS_NODEFILE
    MH_USER=$USER
else
    # non-cluster environment - use at risk!
    MH_WORKDIR=$PWD
    MH_JOBID=$$
    MH_NODEF=$PWD/hosts
    MH_USER=$USER
fi

cd $MH_WORKDIR
 
export HADOOP_CONF_DIR=$MH_WORKDIR/$MH_JOBID

# new myhadoop--figure out how to make this nicer, or extract from elsewhere
cat <<EOF > setenv.sourceme
export HADOOP_HOME="/opt/hadoop"
export MY_HADOOP_HOME="/home/glock/src/myhadoop"
export HADOOP_DATA_DIR="/scratch/$MH_USER/$MH_JOBID/hadoop-$MH_USER/data"
export HADOOP_LOG_DIR="/scratch/$MH_USER/$MH_JOBID/hadoop-$MH_USER/log"
export HADOOP_PID_DIR="/scratch/'$MH_USER'/'$MH_JOBID':' $HADOOP_CONF_DIR/hadoop-env.sh"
export TMPDIR="/scratch/'$MH_USER'/'$MH_JOBID':' $HADOOP_CONF_DIR/hadoop-env.sh"
EOF
source setenv.sourceme

### Generate setenv.sourceme so the user can easily access his or her cluster
mynode=$(/bin/cat $MH_NODEFILE|head -n1)
myjob=$(/bin/cut -d. -f1 <<< $MH_JOBID)
cat << EOF >> setenv.sourceme
export HADOOP_CONF_DIR=$HADOOP_CONF_DIR
export PATH=$HADOOP_HOME/bin:\$PATH
export PATH=/home/glock/python27/bin:\$PATH
export LD_LIBRARY_PATH=/home/glock/python27/lib:\$LD_LIBRARY_PATH
echo "OK, you are all set to use your Hadoop cluster now!"
################################################################################
################################################################################
###
###   Your Hadoop cluster (#$myjob) can be accessed using the following 
###   command:
###
###      ssh $mynode
###
###   After you log in, type
###
###      cd $MH_WORKDIR
###      source setenv.sourceme
###
################################################################################
################################################################################
EOF

### IP over InfiniBand support -- offload this to myhadoop-configure in the future
sed -i 's/^/'$MYHADOOP_IPOIB_PREFIX'/g' $MH_NODEFILE
sed -i 's/$/'$MYHADOOP_IPOIB_SUFFIX'/g' $MH_NODEFILE

MH_NUM_NODES=$(/bin/sort -u $MH_NODEFILE | wc -l)

$MY_HADOOP_HOME/bin/myhadoop-configure.sh -n $MH_NUM_NODES -c $HADOOP_CONF_DIR || exit 1

$HADOOP_HOME/bin/hadoop --config $HADOOP_CONF_DIR namenode -format
 
$HADOOP_HOME/bin/start-all.sh

sleep $MY_HADOOP_LIFETIME

myhadoop-bootstrap-terminate
