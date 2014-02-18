#!/bin/bash
################################################################################
#  myhadoop-bootstrap - call from within a job script to do the entire cluster
#    setup in a hands-off fashion.  This script is admittedly much less useful
#    since etc/myhadoop.conf was added, but it does provide an easy wrapper.
#
#  Glenn K. Lockwood                                             February 2014
################################################################################

### Initialize arguments
MH_LIFETIME=$((6 * 3600))                   # can be overwritten by command line
MH_HOME="$(dirname $(readlink -f $0))/.."

### Command line overrides everything else
if [ "z$1" != "z" ]; then
  MH_LIFETIME=$1
fi

### Cleanup script and signal trap
myhadoop-bootstrap-terminate() {
  $HADOOP_HOME/bin/stop-all.sh
  $MH_HOME/bin/myhadoop-cleanup.sh
  exit
}
trap myhadoop-bootstrap-terminate SIGHUP SIGINT SIGTERM

### We cannot run unless both HADOOP_HOME and MH_HOME are defined
if [ "z$HADOOP_HOME" == "z" -o "z$MH_HOME" == "z" ]; then
  echo 'Error: $HADOOP_HOME or $MH_HOME undefined.  Aborting.' >&2
  exit 1
fi

### Detect our resource manager and populate necessary environment variables
if [ "z$PBS_JOBID" != "z" ]; then
    MH_WORKDIR=$PBS_O_WORKDIR
    MH_JOBID=$PBS_JOBID
elif [ "z$PE_NODEFILE" != "z" ]; then
    MH_WORKDIR=$SGE_O_WORKDIR
    MH_JOBID=$JOB_ID
elif [ "z$SLURM_JOBID" != "z" ]; then
    MH_WORKDIR=$SLURM_SUBMIT_DIR
    MH_JOBID=$SLURM_JOBID
else
    MH_WORKDIR=$PWD
    MH_JOBID=$$
fi

cd $MH_WORKDIR

### If HADOOP_CONF_DIR isn't already in the environment, make one up here
if [ "z$HADOOP_CONF_DIR" == "z" ]; then
  export HADOOP_CONF_DIR=$MH_WORKDIR/$MH_JOBID
fi

### Run myhadoop-configure for the user
$MH_HOME/bin/myhadoop-configure.sh || exit 1

### Generate setenv.sourceme so the user can easily access his or her cluster
cat << EOF >> setenv.sourceme
export HADOOP_HOME="$HADOOP_HOME"
export HADOOP_CONF_DIR=$HADOOP_CONF_DIR
export PATH=$HADOOP_HOME/bin:\$PATH
# You can also include other PATHs, LD_LIBRARY_PATHs, etc here for software
# specific to a class or workshop for which you are using myhadoop-bootstrap
echo "OK, you are all set to use your Hadoop cluster now!"
################################################################################
################################################################################
###
###   Your Hadoop cluster can be accessed using the following command:
###
###      ssh $(uname -n)
###
###   After you log in, type
###
###      cd $MH_WORKDIR
###      source setenv.sourceme
###
################################################################################
################################################################################
EOF

source setenv.sourceme

### Boot up the Hadoop cluster we just configured
$HADOOP_HOME/bin/start-all.sh

sleep $MH_LIFETIME

myhadoop-bootstrap-terminate
