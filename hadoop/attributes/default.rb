default[:Hadoop][:Core][:version] = "2.5.1"
default[:Hadoop][:Core][:hadoopNamenodeDir] = "/home/hduser/hdfs/namenode"
default[:Hadoop][:Core][:hadoopDatanodeDir] = "/home/hduser/hdfs/datanode"
default[:Spark][:Core][:version] = "1.1.0-bin-hadoop2.4"
default[:HBase][:Core][:version] = "0.99.0"
default[:HBase][:Core][:zookeeperDir] = "/home/hduser/zookeeper"
default[:HBase][:Core][:zookeeperQuorumSize] = 3
override[:java][:install_flavor] = "oracle"
override[:java][:oracle][:accept_oracle_download_terms] = true
override[:java][:jdk_version] = "8"
