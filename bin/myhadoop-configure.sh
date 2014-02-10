#!/bin/bash
################################################################################
# myhadoop-configure.sh - establish a valid $HADOOP_CONF_DIR with all of the
#   configurations necessary to start a Hadoop cluster from within a HPC batch
#   environment.  Additionally format HDFS and leave everything in a state ready
#   for Hadoop to start up via start-all.sh.
#
#   Glenn K. Lockwood, San Diego Supercomputer Center
#   Sriram Krishnan, San Diego Supercomputer Center              Feburary 2014
################################################################################

function print_usage {
    echo "Usage: [-n NODES] [-p BASE_DIR] -c CONFIG_DIR -s LOCAL_SCRATCH"
    echo "       -n: Number of nodes requested for the Hadoop installation"
    echo "       -p: Whether the Hadoop installation should be persistent"
    echo "           If so, data directories will have to be linked to a"
    echo "           directory that is not local to enable persistence."
    echo "           BASE_DIR is the location (on a shared filesystem) to"
    echo "           store the namenode and datanodes' persistent states"
    echo "       -c: The directory to become your new HADOOP_CONF_DIR"
    echo "       -h: Print help"
}

function print_nodelist {
    if [ "z$RESOURCE_MGR" == "zpbs" ]; then
        cat $PBS_NODEFILE
    elif [ "z$RESOURCE_MGR" == "zsge" ]; then
        cat $PE_NODEFILE
    elif [ "z$RESOURCE_MGR" == "zslurm" ]; then
	scontrol show hostname $SLURM_NODELIST
    fi
}

# initialize arguments
PERSIST_BASE_DIR=""
HADOOP_CONF_DIR=""
SCRATCH_DIR=""

### Detect our resource manager and populate necessary environment variables
if [ "z$PBS_JOBID" != "z" ]; then
    RESOURCE_MGR="pbs"
elif [ "z$PE_NODEFILE" != "z" ]; then
    RESOURCE_MGR="sge"
elif [ "z$SLURM_JOBID" != "z" ]; then
    RESOURCE_MGR="slurm"
else
    echo "No resource manager detected.  Aborting." >&2
    exit 1
fi

if [ "z$RESOURCE_MGR" == "zpbs" ]; then
    NODES=$PBS_NUM_NODES
    JOBID=$PBS_JOBID
elif [ "z$RESOURCE_MGR" == "zsge" ]; then
    NODES=$NSLOTS
    JOBID=$JOB_ID
elif [ "z$RESOURCE_MGR" == "zslurm" ]; then
    NODES=$SLURM_NNODES
    JOBID=$SLURM_JOBID
fi

### Make sure HADOOP_HOME is set
if [ "z$HADOOP_HOME" == "z" ]; then
    echo 'You must set $HADOOP_HOME before configuring a new cluster.' >&2
    exit 1
fi

### Parse arguments
args=`getopt n:p:c:hs: $*`
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

        -p) shift;
            PERSIST_BASE_DIR=$1
            shift;;

        -c) shift;
            HADOOP_CONF_DIR=$1
            shift;;

        -s) shift;
            SCRATCH_DIR=$1
            shift;;

        -h) shift;
            print_usage
            exit 0
    esac
done

if [ "z$SCRATCH_DIR" == "z" ]; then
    echo "You must specify the local disk filesystem location with -d.  Aborting." >&2
    print_usage
    exit 1
fi

if [ "z$JAVA_HOME" == "z" ]; then
    echo "JAVA_HOME is not defined.  Aborting." >&2
    exit 1
fi

if [ "z$HADOOP_CONF_DIR" == "z" ]; then
    echo "Location of configuration directory not specified.  Aborting." >&2
    print_usage
    exit 1
else 
    echo "Generating Hadoop configuration in directory in $HADOOP_CONF_DIR..."
fi

### Support for persistent HDFS on a shared filesystem
if [ "z$PERSIST_BASE_DIR" != "z" ]; then
    echo "Using directory $PERSIST_BASE_DIR for persisting HDFS state..."
fi

   
### Create the config directory and begin populating it
if [ -d $HADOOP_CONF_DIR ]; then
    i=0
    while [ -d $HADOOP_CONF_DIR.$i ]
    do
        let i++
    done
    echo "Backing up old config dir to $HADOOP_CONF_DIR.$i..."
    mv -v $HADOOP_CONF_DIR $HADOOP_CONF_DIR.$i
fi
mkdir -p $HADOOP_CONF_DIR

### First copy over all default Hadoop configs
cp $HADOOP_HOME/conf/* $HADOOP_CONF_DIR

### Pick the master node as the first node in the nodefile
MASTER_NODE=$(print_nodelist | /usr/bin/head -n1)
echo "Designating $MASTER_NODE as master node (namenode, secondary namenode, and jobtracker)"
echo $MASTER_NODE > $HADOOP_CONF_DIR/masters

### Make every node in the nodefile a slave
print_nodelist | awk '{print $1}' | sort -u | head -n $NODES > $HADOOP_CONF_DIR/slaves
echo "The following nodes will be slaves (datanode, tasktracer):"
cat $HADOOP_CONF_DIR/slaves

### Set the Hadoop configuration files to be specific for our job.  Populate
### the subsitutions to be applied to the conf/*.xml files below.  If you update
### the config_subs hash, be sure to also update myhadoop-cleanup.sh to ensure 
### any new directories you define get properly deleted at the end of the job!
cat <<EOF > $HADOOP_CONF_DIR/myhadoop.conf
NODES=$NODES
declare -A config_subs
config_subs[MASTER_NODE]="$MASTER_NODE"
config_subs[MAPRED_LOCAL_DIR]="$SCRATCH_DIR/mapred_scratch"
config_subs[HADOOP_TMP_DIR]="$SCRATCH_DIR/tmp"
config_subs[DFS_NAME_DIR]="$SCRATCH_DIR/namenode_data"
config_subs[DFS_DATA_DIR]="$SCRATCH_DIR/hdfs_data"
config_subs[HADOOP_LOG_DIR]="$SCRATCH_DIR/logs"
config_subs[HADOOP_PID_DIR]="$SCRATCH_DIR/pids"
EOF

source $HADOOP_CONF_DIR/myhadoop.conf

### And actually apply those substitutions:
for key in "${!config_subs[@]}"; do
  for xml in mapred-site.xml core-site.xml hdfs-site.xml
  do
    sed -i 's#'$key'#'${config_subs[$key]}'#g' $HADOOP_CONF_DIR/$xml
  done
done

### A few Hadoop file locations are set via environment variables:
cat <<EOF >> $HADOOP_CONF_DIR/hadoop-env.sh

# myHadoop alterations for this job:
export HADOOP_LOG_DIR=${config_subs[HADOOP_LOG_DIR]}
export HADOOP_PID_DIR=${config_subs[HADOOP_PID_DIR]}
export HADOOP_HOME_WARN_SUPPRESS=TRUE
export JAVA_HOME=$JAVA_HOME
### Jetty leaves garbage in /tmp no matter what \$TMPDIR is; this is an extreme 
### way of preventing that
# export _JAVA_OPTIONS="-Djava.io.tmpdir=${config_subs[HADOOP_TMP_DIR]} $_JAVA_OPTIONS"

# Other job-specific environment variables follow:
EOF

if [ "z$PERSIST_BASE_DIR" != "z" ]; then
    ### Link HDFS data directories if persistent mode
    i=0
    for node in $(cat $HADOOP_CONF_DIR/slaves $HADOOP_CONF_DIR/masters | sort -u | head -n $NODES)
    do
        mkdir -p $PERSIST_BASE_DIR/$i
        echo "Linking $PERSIST_BASE_DIR/$i to ${config_subs[DFS_DATA_DIR]} on $node"
        ssh $node "mkdir -p $(dirname ${config_subs[DFS_DATA_DIR]}); ln -s $PERSIST_BASE_DIR/$i ${config_subs[DFS_DATA_DIR]}"
        let i++
    done

    ### Also link namenode data directory so we don't lose metadata on shutdown
    namedir=$(basename ${config_subs[DFS_NAME_DIR]})
    mkdir -p $PERSIST_BASE_DIR/$namedir
    for node in $(cat $HADOOP_CONF_DIR/masters | sort -u )
    do
        ssh $node "mkdir -p $(dirname ${config_subs[DFS_NAME_DIR]}); ln -s $PERSIST_BASE_DIR/$namedir ${config_subs[DFS_NAME_DIR]}"
    done
fi

### Format HDFS if it does not already exist from persistent mode
if [ ! -e ${config_subs[DFS_NAME_DIR]}/current ]; then
  HADOOP_CONF_DIR=$HADOOP_CONF_DIR $HADOOP_HOME/bin/hadoop namenode -format -nonInteractive -force
fi
