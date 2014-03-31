Known Issues
------------
No known issues at this time.

Functionality
-------------
* At present, all Hadoop daemons are not secured and assume the underlying 
  cluster environment will provide the necessary access controls to the 
  compute nodes.  Current configuration allows any user and any datanode join
  the existing cluster.  This should be remedied by specifying
  * cluster admin
  * namenode/datanode includes
* integrate spark support directly into myhadoop-configure.sh by checking
  for SPARK_HOME instead of using the separate myspark-configure.sh script

Framework
---------
* separate out the redundant functionality into libexec/myhadoop-driver.sh
* put a "myhadoop" front-end application interface to the backend 
  configure/cleanup scripts
* begin re-implementing backends in perl
* add unit tests
