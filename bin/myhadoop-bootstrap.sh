#!/bin/bash
################################################################################
#  myhadoop-bootstrap - call from within a job script to do the entire cluster
#    setup in a hands-off fashion.
#
#  This script still requires manual intervention in editing the following
#    environment variables:
#    * MY_HADOOP_IPOIB_SUFFIX
#    * MY_HADOOP_IPOIB_PREFIX
#    * MY_HADOOP_LIFETIME
#    * SCRATCH_DIR
#
#  It is considered experimental and is still in the process of being updated
#  to be as flexible as possible.
#
#  Glenn K. Lockwood                                             January 2014
################################################################################

MY_HADOOP_IBOIB_SUFFIX=".ibnet0"
MY_HADOOP_IBOIB_PREFIX=""
MY_HADOOP_LIFETIME=$((6 * 3600))
SCRATCH_DIR=/scratch/$USER/$PBS_JOBID

### Cleanup script and signal trap
myhadoop-bootstrap-terminate() {
  $HADOOP_HOME/bin/stop-all.sh
  $MY_HADOOP_HOME/bin/myhadoop-cleanup.sh
  exit
}
trap myhadoop-bootstrap-terminate SIGHUP SIGINT SIGTERM

### We cannot run unless both HADOOP_HOME and MY_HADOOP_HOME are defined
if [ "z$HADOOP_HOME" == "z" -o "z$MY_HADOOP_HOME" == "z" ]; then
  echo 'Error: $HADOOP_HOME or $MY_HADOOP_HOME undefined.  Aborting.' >&2
  exit 1
fi

### Detect our resource manager and populate necessary environment variables
if [ "z$PBS_JOBID" != "z" ]; then
    RESOURCE_MGR="pbs"
elif [ "z$PE_NODEFILE" != "z" ]; then
    RESOURCE_MGR="sge"
elif [ "z$SLURM_JOBID" != "z" ]; then
    RESOURCE_MGR="slurm"
fi

### Extract the necessary environment variables
if [ "z$RESOURCE_MGR" == "zpbs" ]; then
    # PBS/Torque
    MH_WORKDIR=$PBS_O_WORKDIR
    MH_JOBID=$PBS_JOBID
    MH_NODEFILE=$PBS_NODEFILE
elif [ "z$RESOURCE_MGR" == "zsge" ]; then
    MH_WORKDIR=$SGE_O_WORKDIR
    MH_JOBID=$JOB_ID
    MH_NODEFILE=$PE_NODEFILE
elif [ "z$RESOURCE_MGR" == "zslurm" ]; then
    MH_WORKDIR=$SLURM_SUBMIT_DIR
    MH_JOBID=$SLURM_JOBID
    MH_NODEFILE=$(mktemp)
    scontrol show hostname $SLURM_NODELIST > $MH_NODEFILE
else
    # non-cluster environment - use at risk!
    MH_WORKDIR=$PWD
    MH_JOBID=$$
    MH_NODEFILE=$PWD/hosts
fi

cd $MH_WORKDIR
 
export HADOOP_CONF_DIR=$MH_WORKDIR/$MH_JOBID

### Generate setenv.sourceme so the user can easily access his or her cluster
mynode=$(/bin/cat $MH_NODEFILE|head -n1)
myjob=$(/bin/cut -d. -f1 <<< $MH_JOBID)
cat << EOF >> setenv.sourceme
export HADOOP_HOME="$HADOOP_HOME"
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

$MY_HADOOP_HOME/bin/myhadoop-configure.sh -c $HADOOP_CONF_DIR -s /scratch/$USER/$PBS_JOBID || exit 1

$HADOOP_HOME/bin/start-all.sh

sleep $MY_HADOOP_LIFETIME

myhadoop-bootstrap-terminate
