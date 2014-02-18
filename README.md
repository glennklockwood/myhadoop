# myHadoop

This represents the logical continuation of the myhadoop project by Sriram 
Krishnan (http://sourceforge.net/projects/myhadoop/).

myhadoop provides a framework for launching Hadoop clusters within traditional 
high-performance compute clusters and supercomputers.  It allows users to 
provision and deploy Hadoop clusters within the batch scheduling environment of
such systems with minimal expertise required.

## Quick Install

Assuming you unpacked myHadoop in /usr/local/myhadoop and your Hadoop binary
distribution is located in /usr/local/hadoop-1.2.1:

    cd /usr/local/hadoop-1.2.1/conf
    patch < /usr/local/myhadoop/myhadoop-1.2.1.patch

That's it.  See USERGUIDE.md for a more detailed installation guide and a brief
introduction to using myHadoop.

## About myHadoop
This framework comes with three principal runtimes:

* bin/myhadoop-configure.sh - creates a Hadoop configuration set based on the
  information presented by a system's batch scheduler.  At present, myhadoop
  interfaces with Torque, SLURM, and Sun Grid Engine.
* bin/myhadoop-cleanup.sh - cleans up after the Hadoop cluster has been torn
  down.
* bin/myhadoop-bootstrap.sh - When run from either within a job submission 
  script or an interactive job, it provides a one-command configuration and 
  spinup of a Hadoop cluster and instructions for the user on how to connect 
  to his or her personal cluster.

### myhadoop-configure.sh

This script takes a series of template configuration XML files, applies the 
necessary patches based on the job runtime environment provided by the batch
scheduler, and (optionally) formats HDFS.  The general syntax is

myhadoop-configure.sh -c /your/new/config/dir -s /path/to/node/local/storage

where
  * /your/new/config/dir is where you would like your Hadoop cluster's config
    directory to reside.  This is a relatively arbitrary choice, but it will 
    then serve as your Hadoop cluster's $HADOOP_CONF_DIR
  * /path/to/node/local/storage is the location of a non-shared filesystem on
    each node that can be used to store each node's configuration, state, and
    HDFS data.

The examples/ directory contains torque.qsub which illustrates how this
would look in practice.

Before calling myhadoop-configure.sh, you MUST have JAVA_HOME defined in your 
environment and HADOOP_HOME defined in either your environment or your
myhadoop/etc/myhadoop.conf file.  myhadoop-configure.sh will look in 
$HADOOP_HOME/conf for the configuration templates it will use for your personal
Hadoop cluster.

### myhadoop-cleanup.sh

This is a courtesy script that simply deletes all of the data created by a
Hadoop cluster on all of the cluster's nodes.  A proper batch system should do
this automatically.

To run myhadoop-cleanup.sh, you must have HADOOP_HOME and HADOOP_CONF_DIR
defined in your environment.

### myhadoop-bootstrap.sh

This is another courtesy script that wraps myhadoop-configure.sh to simplify
the process of creating Hadoop clusters for users.  When run from within a
batch environment (e.g., a batch job or an interactive job), it will gather
the necessary information from the batch system to run myhadoop-configure.sh,
run it, and create a file called "setenv.sourceme" that contains all of the
instructions a user will need to connect to his or her newly spawned Hadoop
cluster and begin using it.

The examples/ directory contains bootstrap.qsub that illustrates how a user may 
use myhadoop-boostrap.sh in all supported batch environments.  He or she simply
has to submit this script and wait for "setenv.sourceme" to appear in his or 
her directory.  Once it appears, he or she can "cat" the file and follow the 
instructions contained within to get to an environment where he or she can 
begin interacting with his or her cluster using the "hadoop" command.
