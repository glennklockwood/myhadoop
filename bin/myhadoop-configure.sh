#!/bin/bash

function print_usage {
    echo "Usage: [-n NODES] [-p -d BASE_DIR] -c CONFIG_DIR -s LOCAL_SCRATCH"
    echo "       -n: Number of nodes requested for the Hadoop installation"
    echo "       -p: Whether the Hadoop installation should be persistent"
    echo "           If so, data directories will have to be linked to a"
    echo "           directory that is not local to enable persistence"
    echo "       -d: Base directory to persist HDFS state, to be used if"
    echo "           -p is set"
    echo "       -c: The directory to become your new HADOOP_CONF_DIR"
    echo "       -h: Print help"
}

# initialize arguments
PERSIST="false"
PERSIST_BASE_DIR=""
HADOOP_CONF_DIR=""
SCRATCH_DIR=""

### Detect our resource manager and populate necessary environment variables
if [ "z$PBS_NODEFILE" != "z" ]; then
    RESOURCE_MGR="pbs"
elif [ "z$PE_NODEFILE" != "z" ]; then
    RESOURCE_MGR="sge"
else
    echo "No resource manager detected.  Aborting." >&2
    exit 1
fi

if [ "z$RESOURCE_MGR" == "zpbs" ]; then
    NODES=$PBS_NUM_NODES
    NODEFILE=$PBS_NODEFILE
    JOBID=$PBS_JOBID
elif [ "z$RESOURCE_MGR" == "zsge" ]; then
    NODES=$NSLOTS
    NODEFILE=$PE_NODEFILE
    JOBID=$JOB_ID
fi

### Make sure HADOOP_HOME is set
if [ "z$HADOOP_HOME" == "z" ]; then
    echo 'You must set $HADOOP_HOME before configuring a new cluster.' >&2
    exit 1
fi

### Parse arguments
args=`getopt n:pd:c:hs: $*`
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
            PERSIST_BASE_DIR=$1
            shift;;

        -c) shift;
            HADOOP_CONF_DIR=$1
            shift;;

        -s) shift;
            SCRATCH_DIR=$1
            shift;;

        -p) shift;
            PERSIST="true"
            ;;

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

if [ "z$HADOOP_CONF_DIR" == "z" ]; then
    echo "Location of configuration directory not specified.  Aborting." >&2
    print_usage
    exit 1
else 
    echo "Generating Hadoop configuration in directory in $HADOOP_CONF_DIR..."
fi

### Support for persistent HDFS on a shared filesystem
if [ "$PERSIST" == "true" ]; then
    echo "Enabling persistent HDFS state..."
    if [ "$PERSIST_BASE_DIR" = "" ]; then
        echo "Base directory (-d) not set for persisting HDFS state.  Aborting." >&2
        print_usage
        exit 1
    else
        echo "Using directory $PERSIST_BASE_DIR for persisting HDFS state..."
    fi
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
MASTER_NODE=$(/usr/bin/head -n1 $NODEFILE)
echo "Designating $MASTER_NODE as master node (namenode, secondary namenode, and jobtracker)"
echo $MASTER_NODE > $HADOOP_CONF_DIR/masters

### Make every node in the nodefile a slave
awk '{print $1}' $NODEFILE | sort -u | head -n $NODES > $HADOOP_CONF_DIR/slaves
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
### Jetty leaves garbage in /tmp no matter what \$TMPDIR is; this is an extreme 
### way of preventing that
# export _JAVA_OPTIONS="-Djava.io.tmpdir=${config_subs[HADOOP_TMP_DIR]} $_JAVA_OPTIONS"

# Other job-specific environment variables follow:
EOF

### Link HDFS data directories if persistent mode
if [ "$PERSIST" = "true" ]; then
    for node in $(cat $HADOOP_CONF_DIR/slaves $HADOOP_CONF_DIR/masters | sort -u | head -n $NODES)
    do
        ssh $node "ln -s $PERSIST_BASE_DIR/$i ${config_subs[DFS_DATA_DIR]}"
    done
### Otherwise, format HDFS
else
    HADOOP_CONF_DIR=$HADOOP_CONF_DIR $HADOOP_HOME/bin/hadoop namenode -format
fi
