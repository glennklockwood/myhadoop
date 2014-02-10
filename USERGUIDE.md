# myHadoop User Guide

This guide assumes the following:

* Users are allowed to ssh into and between nodes allocated for their job 
  without having to provide a password
* Users are allowed to open ports > 1024 on their jobs' nodes
* Each node has a local scratch space that is not shared between 
  nodes† and users can write to it.
* For the sake of simplicity, we also assume nodes are not shared between jobs.
  Hadoop stresses aspects of the system (like I/O) that are not typically 
  considered in resource allocation, so having Hadoop and non-Hadoop jobs on a 
  shared node introduces a lot of unnecessary complexity.

We are also installing Apache Hadoop version 1, as opposed to version 2. This 
is a critical distinction because Hadoop version 2 is architecturally (and 
configurationally) very different from version 1. Hadoop 1 is what is in 
widespread production today, and it is the version for which most of the 
Hadoop application ecosystem has been developed. In the future I will be 
incorporating Hadoop2/YARN support into myHadoop, it's not there yet.

The exact version of Hadoop 1 we're using is less important; I am using the 
latest (as of this writing) version of Hadoop 1.2.1, although there is no 
reason this system would not work for earlier versions; we've tested using 
1.0.4, 1.1.1, and the ancient 0.20 releases.

† Although this guide assumes each node has its own user-writeable local 
scratch, this is not a requirement for deploying Hadoop on traditional 
supercomputers. I will try to cover the more advanced topic of running Hadoop 
on shared/parallel filesystems in a future guide.

# Basic Software Installation

## Install Hadoop 1.2.1 and myHadoop 0.30b

You can download the tarballs from the following locations:

* [hadoop-1.2.1-bin.tar.gz](http://www.apache.org/dyn/closer.cgi/hadoop/common/)
* [myhadoop](https://github.com/glennklockwood/myhadoop)

Neither of these tarballs requires any sort of proper "installation;" simply 
unpack them wherever you'd like to have them be installed, e.g.,

    $ mkdir ~/hadoop-stack
    $ cd ~/hadoop-stack
    $ tar zxvf hadoop-1.2.1-bin.tar.gz
    hadoop-1.2.1/
    hadoop-1.2.1/.eclipse.templates/
    hadoop-1.2.1/.eclipse.templates/.externalToolBuilders/
    hadoop-1.2.1/.eclipse.templates/.launches/
    hadoop-1.2.1/bin/
    hadoop-1.2.1/c++/
    ...
 
    $ tar zxvf myhadoop-0.30b.tar.gz
    myhadoop-0.30b/
    myhadoop-0.30b/CHANGELOG
    myhadoop-0.30b/LICENSE
    myhadoop-0.30b/README.md
    myhadoop-0.30b/bin/
    myhadoop-0.30b/bin/myhadoop-bootstrap.sh
    ...

## Patch the Hadoop Configuration

myHadoop ships with a patch file, myhadoop-1.2.1.patch, that converts the 
default configuration files that ship with Apache Hadoop into templates that 
myHadoop can then copy and modify when a user wants to run a job. To apply 
that patch,

    $ cd hadoop-1.2.1/conf
    $ patch < ../../myhadoop-0.30b/myhadoop-1.2.1.patch
    patching file core-site.xml
    patching file hdfs-site.xml
    patching file mapred-site.xml

...and that's it. You now have Hadoop installed on your cluster.

# Starting up a Hadoop Cluster

When you want to spin up a Hadoop cluster, you will need to do the following 
from within a job environment--either a non-interactive job script, or an 
interactive job.

## Step 1. Define $HADOOP_HOME

Define $HADOOP_HOME, which in the previous section's example, would be 
$HOME/hadoop-stack/hadoop-1.2.1:

    $ export HADOOP_HOME=$HOME/hadoop-stack/hadoop-1.2.1

myHadoop needs to know where this is because $HADOOP_HOME/conf contains the 
patched configuration templates it will use to build actual cluster 
configurations.

Adding $HADOOP_HOME/bin and your myHadoop installation directory to $PATH is 
just a matter of additional convenience:

    $ export PATH=$HADOOP_HOME/bin:$PATH
    $ export PATH=$HOME/hadoop-stack/myhadoop-0.30b/bin:$PATH

In the event that your system does not have $JAVA_HOME properly set either, 
you must also define that.

    $ export JAVA_HOME=/usr/java/latest

## Step 2. Choose a $HADOOP_CONF_DIR

Define $HADOOP_CONF_DIR, which will be where your personal cluster's 
configuration will be located. This is an arbitrary choice, but I like to use 
the jobid, e.g.,

    $ export HADOOP_CONF_DIR=$HOME/mycluster-conf-$PBS_JOBID

to ensure that running multiple Hadoop cluster jobs on the same supercomputer 
doesn't cause them all to step on each others' config directories.

## Step 3. Run myhadoop-configure.sh

The myhadoop-configure.sh script (which is in the bin/ directory of your 
myHadoop install directory) extracts all of the job information (node names, 
node count, etc) from your supercomputer's resource manager (Torque, Grid 
Engine, SLURM, etc) and populates the configuration directory ($HADOOP_CONF_DIR) 
with the Hadoop config files necessary to make the Hadoop cluster use the 
nodes and resources assigned to it by the resource manager.

The general syntax for myhadoop-configure.sh

    $ myhadoop-configure.sh -c $HADOOP_CONF_DIR -s /scratch/$USER/$PBS_JOBID

where

* `-c $HADOOP_CONF_DIR` specifies the directory where your Hadoop cluster 
  configuration should reside. Provided you defined the $HADOOP_CONF_DIR 
  environment variable as recommended above, this will always be what you 
  specify with the -c flag.
* -s /scratch/$USER/$PBS_JOBID specifies the location of the scratch space 
  local to each compute node. This directory should reside on a local 
  filesystem on each compute node, and it cannot be a shared filesystem.

Upon running this myhadoop-configure.sh script, $HADOOP_CONF_DIR will be 
created and populated with the necessary configuration files. In addition, the 
HDFS filesystem for this new Hadoop cluster will be created (in the directory 
specified after the -s flag on each compute node) and formatted.

## Step 4. Start the Hadoop cluster

Once myhadoop-configure.sh has been run, the Hadoop cluster is ready to go. 
Once again, ensure that the $HADOOP_CONF_DIR environment variable is defined, 
and then use the start-all.sh script that comes with Hadoop (it's located in 
$HADOOP_HOME/bin).

    $ $HADOOP_HOME/bin/start-all.sh
    Warning: $HADOOP_HOME is deprecated.
 
    starting namenode, logging to /scratch/username/1234567.master/logs/hadoop-username-namenode-node-6-78.sdsc.edu.out
    node-6-78: Warning: $HADOOP_HOME is deprecated.
    node-6-78:
    node-6-78: starting datanode, logging to /scratch/username/1234567.master/logs/hadoop-username-datanode-node-6-78.sdsc.edu.out
    ...

The warnings about $HADOOP_HOME being deprecated are harmless and the result of 
Hadoop 1.x (as opposed to 0.20) preferring $HADOOP_PREFIX instead of 
$HADOOP_HOME. If you find it extremely annoying, you can add export 
HADOOP_HOME_WARN_SUPPRESS=TRUE to your ~/.bashrc to suppress it.

To verify that your Hadoop cluster is up and running, you can do something like

    $ hadoop dfsadmin -report
    Configured Capacity: 899767603200 (837.97 GB)
    Present Capacity: 899662729261 (837.88 GB)
    DFS Remaining: 899662704640 (837.88 GB)
    DFS Used: 24621 (24.04 KB)
    DFS Used%: 0%
    Under replicated blocks: 0
    Blocks with corrupt replicas: 0
    Missing blocks: 0
     
    -------------------------------------------------
    Datanodes available: 3 (3 total, 0 dead)
     
    Name: 10.5.101.146:50010
    ...

Or you can try making a few directories on HDFS and loading up some examples...

    $ hadoop dfs -mkdir data
     
    $ wget http://www.gutenberg.org/cache/epub/2701/pg2701.txt
    ...
    2014-02-09 14:01:12 (939 KB/s) - "pg2701.txt" saved [1257274/1257274]
     
    $ hadoop dfs -put pg2701.txt data/
     
    $ hadoop dfs -ls data
    Found 1 items
    -rw-r--r--   3 username supergroup    1257274 2014-02-09 14:01 /user/username/data/pg2701.txt

And running the wordcount example that comes with Hadoop:

    $ hadoop jar $HADOOP_HOME/hadoop-examples-1.2.1.jar wordcount data/pg2701.txt wordcount-output
    14/02/09 14:03:21 INFO input.FileInputFormat: Total input paths to process : 1
    14/02/09 14:03:21 INFO util.NativeCodeLoader: Loaded the native-hadoop library
    14/02/09 14:03:21 WARN snappy.LoadSnappy: Snappy native library not loaded
    14/02/09 14:03:21 INFO mapred.JobClient: Running job: job_201402091353_0001
    14/02/09 14:03:22 INFO mapred.JobClient:  map 0% reduce 0%
    14/02/09 14:03:27 INFO mapred.JobClient:  map 100% reduce 0%
    14/02/09 14:03:34 INFO mapred.JobClient:  map 100% reduce 33%
    14/02/09 14:03:36 INFO mapred.JobClient:  map 100% reduce 100%
    14/02/09 14:03:37 INFO mapred.JobClient: Job complete: job_201402091353_0001
    14/02/09 14:03:37 INFO mapred.JobClient: Counters: 29
    ...

And verify the output:

    $ hadoop dfs -cat wordcount-output/part-r-00000
    "'A 3
    "'Also  1
    "'Are   1
    "'Aye,  2
    ...

## Step 5. Stop the Hadoop cluster

Once you are done with your Hadoop cluster, you can stop it using the 
stop-all.sh script provided with Hadoop:

    $ stop-all.sh
    stopping jobtracker
    gcn-6-78: stopping tasktracker
    gcn-7-85: stopping tasktracker
    ...
    stopping namenode
    gcn-7-85: stopping datanode
    gcn-6-78: stopping datanode
    ...
    gcn-6-78: stopping secondarynamenode

Then run the myhadoop-cleanup.sh script included with myHadoop. It will copy the
Hadoop logfiles off of your jobtracker (useful for debugging failed jobs) and 
put them in your $HADOOP_CONF_DIR, then delete all of the temporary files that 
Hadoop creates all over each compute node.

    $ myhadoop-cleanup.sh
    Copying Hadoop logs back to /home/username/mycluster-conf-1234567.master/logs...
    ...
    removed directory: `/scratch/username/1234567.master/mapred_scratch/taskTracker'
    removed directory: `/scratch/username/1234567.master/mapred_scratch/ttprivate'
    ...

Strictly speaking, neither of these steps (stop-all.sh and myhadoop-cleanup.sh) 
are necessary since most supercomputers will clean up temporary user files on 
each node after your job ends, but it doesn't hurt to do these two steps 
explicitly to save on potential headaches.

## Advanced Features

### Persistent mode

Although the preferred way of using myHadoop and HDFS is using node-local disk
for HDFS, this has the drawback of the HDFS state not persisting once your
myHadoop job ends and the node-local scratch space is (presumably) purged by
the resource manager.

To address this limitation, myHadoop also provides a "persistent" mode whereby
the namenode and all datanodes are actually stored on some persistent, shared
filesystem (like Lustre) and linked to each Hadoop node at the same location
in a node-local filesystem.

To configure a "persistent" myHadoop cluster, add the -p flag to specify a
location on the shared filesystem to act as the true storage backend for all
of your datanodes and namenode, e.g.,

    myhadoop-configure.sh -p /path/to/shared/filesystem \
                          -c /your/new/config/dir \
                          -s /path/to/node/local/storage

In this case, /path/to/shared/filesystem would be your space on a filesystem
accessible to all of your Hadoop nodes, /your/new/config/dir is the same
arbitrary configuration directory for the cluster you want to spin up (this
does not need to be the same as any previous persistent states), and
/path/to/node/local/storage remains a path to a filesystem that is NOT shared
across nodes (e.g., /tmp).

Persistent mode then creates directories under /path/to/shared/filesystem that 
stores the datanode and HDFS data for each datanode.  In addition, it creates
a /path/to/shared/filesystem/namenode_data directory which contains the namenode
state (e.g., fsimage).  It then creates symlinks in /path/to/node/local/storage
pointing to /path/to/shared/filesystem on each datanode to point to this shared
filesystem.

You can then safely run your map/reduce jobs, stop-all.sh to shut down the
cluster, and even myhadoop-cleanup.sh to wipe out your compute nodes.  At a 
later time, you can request a new set of nodes from your supercomputer's batch
scheduler, run the same myhadoop-configure.sh command with the -p option
pointing to the same /path/to/shared/filesystem, and myHadoop will detect an
existing persistent HDFS state and adjust the resulting Hadoop cluster 
configurations accordingly.  You can use this mechanism to store data on HDFS
even when you have no jobs running in the batch system.

*IMPORTANT NOTE*: Use of persistent mode is not recommended, as Hadoop's
performance and resiliency arises from the fact that HDFS resides on physically
discrete storage devices.  By pointing all of your datanodes' HDFS blocks at
the same persistent storage device (a SAN, NFS-mounted storage, etc), you lose 
the data parallelism and resulting perfomance that makes Hadoop useful.  You 
are, in effect, shooting yourself in the foot by doing this.  The only potential
exception to this is if you use a parallel clustered filesystem (like Lustre)
as the persistent storage device; the parallelism underneath that filesystem
may allow you to recover some of the performance loss because it will store
your HDFS blocks on different object storage targets.  However, other 
bottlenecks and limitations also enter the picture.
