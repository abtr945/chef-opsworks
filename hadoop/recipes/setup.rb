# Step 1: Enable plain-text password SSH authorization

log "start_1" do
  message "<AN_TRAN> STEP 1: Enable plain-text password SSH authorization started"
  level :info
end

# Install sshpass to automatically provide password
package "sshpass"

# Enable password SSH authorization in config file
template "/etc/ssh/sshd_config" do
  mode "0644"
  source "sshd_config.erb"
end

# Restart SSH service
service "ssh" do
  supports :restart => true, :reload => true
  action :enable
  subscribes :reload, "template[/etc/ssh/sshd_config]", :immediately
end

log "complete_1" do
  message "<AN_TRAN> STEP 1: Enable plain-text password SSH authorization completed"
  level :info
end


# Step 2: Install Oracle Java

log "start_2" do
  message "<AN_TRAN> STEP 2: Install Oracle Java started"
  level :info
end

include_recipe "java"

log "complete_2" do
  message "<AN_TRAN> STEP 2: Install Oracle Java completed"
  level :info
end


# Step 3: Create Hadoop user

log "start_3" do
  message "<AN_TRAN> STEP 3: Create Hadoop user started"
  level :info
end

script "create_user" do
  interpreter "bash"
  user "root"
  code <<-EOH
  sudo addgroup hadoop
  sudo useradd --gid hadoop -m hduser
  echo -e "password\npassword" | (sudo passwd hduser)
  sudo adduser hduser sudo
  EOH
end

log "complete_3" do
  message "<AN_TRAN> STEP 3: Create Hadoop user completed"
  level :info
end


# Step 4: Set Environment variables

log "start_4" do
  message "<AN_TRAN> STEP 4: Set Environment variables started"
  level :info
end

if node[:opsworks][:instance][:hostname] == "master"

  template "/home/hduser/.bashrc" do
    owner "hduser"
    group "hadoop"
    mode "0644"
    source "spark.bashrc.erb"
  end

else

  template "/home/hduser/.bashrc" do
    owner "hduser"
    group "hadoop"
    mode "0644"
    source "bashrc.erb"
  end

end

log "complete_4" do
  message "<AN_TRAN> STEP 4: Set Environment variables completed"
  level :info
end


# Step 5: (Master only) Create SSH Public Key

if node[:opsworks][:instance][:hostname] == "master"

  log "start_5" do
    message "<AN_TRAN> STEP 5: (Master only) Create SSH Public Key started"
    level :info
  end

  script "ssh-keygen" do
    interpreter "bash"
    user "hduser"
    code <<-EOH
    ssh-keygen -t rsa -P "" -f /home/hduser/.ssh/id_rsa
    cat /home/hduser/.ssh/id_rsa.pub >> /home/hduser/.ssh/authorized_keys
    EOH
  end

  log "complete_5" do
    message "<AN_TRAN> STEP 5: (Master only) Create SSH Public Key completed"
    level :info
  end

else

  log "ssh_not_master" do
    message "<AN_TRAN> STEP 5: (Master only) Create SSH Public Key - This is not a master node, do nothing"
    level :info
  end
  
end


# Step 6: Install Hadoop

log "start_6" do
  message "<AN_TRAN> STEP 6: Install Hadoop started"
  level :info
end

script "download_unpack_hadoop" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  wget http://apache.mirror.serversaustralia.com.au/hadoop/common/hadoop-#{node[:Hadoop][:Core][:version]}/hadoop-#{node[:Hadoop][:Core][:version]}.tar.gz
  tar -xf hadoop-#{node[:Hadoop][:Core][:version]}.tar.gz -C /usr/local
  ln -s /usr/local/hadoop-#{node[:Hadoop][:Core][:version]} /usr/local/hadoop  
  chown -R hduser:hadoop /usr/local/hadoop-#{node[:Hadoop][:Core][:version]}
  EOH
end

file "/tmp/hadoop-#{node[:Hadoop][:Core][:version]}.tar.gz" do
  action :delete
end

log "complete_6" do
  message "<AN_TRAN> STEP 6: Install Hadoop completed"
  level :info
end


# Step 7: Configure hadoop-env.sh

log "start_7" do
  message "<AN_TRAN> STEP 7: Configure hadoop-env.sh started"
  level :info
end

# Write the configuration from template
template "/usr/local/hadoop/etc/hadoop/hadoop-env.sh" do
  owner "hduser"
  group "hadoop"
  mode "0644"
  source "hadoop-env.sh.erb"
end

log "complete_7" do
  message "<AN_TRAN> STEP 7: Configure hadoop-env.sh completed"
  level :info
end


# Step 8: Configure *-site.xml

log "start_8" do
  message "<AN_TRAN> STEP 8: Configure Hadoop *-site.xml started"
  level :info
end

template "/usr/local/hadoop/etc/hadoop/core-site.xml" do
  owner "hduser"
  group "hadoop"
  mode "0644"
  source "core-site.xml.erb"
end

template "/usr/local/hadoop/etc/hadoop/yarn-site.xml" do
  owner "hduser"
  group "hadoop"
  mode "0644"
  source "yarn-site.xml.erb"
end

if node[:opsworks][:instance][:hostname] == "master"

  # Setup phase use default dfs.replication value of 3
  template "/usr/local/hadoop/etc/hadoop/hdfs-site.xml" do
    owner "hduser"
    group "hadoop"
    mode "0644"
    source "master.hdfs-site.xml.erb"
    variables({
      :dfsReplication => "3"
    })
  end
  
else

  # Setup phase use default dfs.replication value of 3
  template "/usr/local/hadoop/etc/hadoop/hdfs-site.xml" do
    owner "hduser"
    group "hadoop"
    mode "0644"
    source "slave.hdfs-site.xml.erb"
    variables({
      :dfsReplication => "3"
    })
  end

end

log "complete_8" do
  message "<AN_TRAN> STEP 8: Configure Hadoop *-site.xml completed"
  level :info
end


# Step 9: Create data directories

log "start_9" do
  message "<AN_TRAN> STEP 9: Create data directories started"
  level :info
end

# Create Namenode directory
directory node[:Hadoop][:Core][:hadoopNamenodeDir] do
  owner "hduser"
  group "hadoop"
  mode "0770"
  recursive true
  action :create
end

# Create Datanode directory
directory node[:Hadoop][:Core][:hadoopDatanodeDir] do
  owner "hduser"
  group "hadoop"
  mode "0770"
  recursive true
  action :create
end

# Create Hadoop logs directory
directory "/usr/local/hadoop/logs" do
  owner "hduser"
  group "hadoop"
  mode "0770"
  recursive true
  action :create
end

log "complete_9" do
  message "<AN_TRAN> STEP 9: Create data directories completed"
  level :info
end


# ----------------------- INSTALL APACHE SPARK ---------------------------


# Step 10: (Master only) Install Apache Spark on Master node

if node[:opsworks][:instance][:hostname] == "master"

  log "start_10" do
    message "<AN_TRAN> STEP 10: (Master only) Install Apache Spark on Master node started"
    level :info
  end
  
  script "download_unpack_spark" do
    interpreter "bash"
    user "root"
    cwd "/tmp"
    code <<-EOH
    wget http://d3kbcqa49mib13.cloudfront.net/spark-#{node[:Spark][:Core][:version]}.tgz
    tar -xf spark-#{node[:Spark][:Core][:version]}.tgz -C /usr/local
    ln -s /usr/local/spark-#{node[:Spark][:Core][:version]} /usr/local/spark
    chown -R hduser:hadoop /usr/local/spark-#{node[:Spark][:Core][:version]}
    EOH
  end
  
  log "complete_10" do
    message "<AN_TRAN> STEP 10: (Master only) Install Apache Spark on Master node completed"
    level :info
  end
  
else

  log "spark_not_master" do
    message "<AN_TRAN> STEP 10: (Master only) Install Apache Spark - This is not a master node, do nothing"
    level :info
  end

end


# ----------------------- INSTALL APACHE HBASE ---------------------------


# Step 11: Install Apache HBase

log "start_11" do
  message "<AN_TRAN> STEP 11: Install Apache HBase started"
  level :info
end

script "download_unpack_hbase" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  wget http://apache.mirror.uber.com.au/hbase/hbase-#{node[:HBase][:Core][:version]}/hbase-#{node[:HBase][:Core][:version]}-bin.tar.gz
  tar -xf hbase-#{node[:HBase][:Core][:version]}-bin.tar.gz -C /usr/local
  ln -s /usr/local/hbase-#{node[:HBase][:Core][:version]} /usr/local/hbase
  chown -R hduser:hadoop /usr/local/hbase-#{node[:HBase][:Core][:version]}
  EOH
end

log "complete_11" do
  message "<AN_TRAN> STEP 11: Install Apache HBase completed"
  level :info
end


# Step 12: Configure HBase and Zookeeper

log "start_12" do
  message "<AN_TRAN> STEP 12: Configure HBase and Zookeeper started"
  level :info
end

template "/usr/local/hbase/conf/hbase-env.sh" do
  owner "hduser"
  group "hadoop"
  mode "0644"
  source "hbase-env.sh.erb"
end

# Initialize Zookeeper quorum to just "master" node
template "/usr/local/hbase/conf/hbase-site.xml" do
  owner "hduser"
  group "hadoop"
  mode "0644"
  source "hbase-site.xml.erb"
  variables({
    :zookeeperQuorum => "master"
  })
end

# Create symlink to hdfs-site.xml
execute "create_hdfs_symlink" do
  user "root"
  command "ln -s /usr/local/hadoop/etc/hadoop/hdfs-site.xml /usr/local/hbase/conf/hdfs-site.xml"
end

log "complete_12" do
  message "<AN_TRAN> STEP 12: Configure HBase and Zookeeper completed"
  level :info
end


# Step 13: Create Zookeeper data directory

log "start_13" do
  message "<AN_TRAN> STEP 13: Create Zookeeper data directory started"
  level :info
end

directory node[:HBase][:Core][:zookeeperDir] do
  owner "hduser"
  group "hadoop"
  mode "0770"
  recursive true
  action :create
end

log "complete_13" do
  message "<AN_TRAN> STEP 13: Create Zookeeper data directory completed"
  level :info
end


# Step 14: Replace Hadoop bundled JARs in HBase lib with latest version

log "start_14" do
  message "<AN_TRAN> STEP 14: Replace Hadoop bundled JARs in HBase lib with latest version started"
  level :info
end

hadoop_jars_old = [ "hadoop-annotations-2.4.0.jar", 
                    "hadoop-auth-2.4.0.jar", 
                    "hadoop-client-2.4.0.jar", 
                    "hadoop-common-2.4.0.jar", 
                    "hadoop-hdfs-2.4.0.jar", 
                    "hadoop-mapreduce-client-app-2.4.0.jar", 
                    "hadoop-mapreduce-client-common-2.4.0.jar", 
                    "hadoop-mapreduce-client-core-2.4.0.jar", 
                    "hadoop-mapreduce-client-jobclient-2.4.0.jar", 
                    "hadoop-mapreduce-client-shuffle-2.4.0.jar", 
                    "hadoop-yarn-api-2.4.0.jar", 
                    "hadoop-yarn-client-2.4.0.jar", 
                    "hadoop-yarn-common-2.4.0.jar", 
                    "hadoop-yarn-server-common-2.4.0.jar", 
                    "hadoop-yarn-server-nodemanager-2.4.0.jar" ]
					
hadoop_jars_new = [ "hadoop-annotations-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-auth-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-client-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-common-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-hdfs-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-mapreduce-client-app-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-mapreduce-client-common-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-mapreduce-client-core-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-mapreduce-client-jobclient-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-mapreduce-client-shuffle-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-yarn-api-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-yarn-client-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-yarn-common-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-yarn-server-common-#{node[:Hadoop][:Core][:version]}.jar", 
                    "hadoop-yarn-server-nodemanager-#{node[:Hadoop][:Core][:version]}.jar" ]

script "copy_new_hadoop_jars_directory" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  cp -r /usr/local/hadoop/share/hadoop /tmp
  mkdir flatten
  wget -P /tmp/flatten/ http://central.maven.org/maven2/org/apache/hadoop/hadoop-client/#{node[:Hadoop][:Core][:version]}/hadoop-client-#{node[:Hadoop][:Core][:version]}.jar
  EOH
end

execute "flatten_new_hadoop_jars_directory" do
  user "root"
  command "find /tmp/hadoop/ -mindepth 2 -type f -exec mv '{}' /tmp/flatten ';'"
end

hadoop_jars_old.each do |jar_old|
  execute "remove_#{jar_old}" do
    user "root"
    command "rm -f /usr/local/hbase/lib/#{jar_old}"
  end
end

hadoop_jars_new.each do |jar_new|
  execute "replace_with_#{jar_new}" do
    user "root"
    command "mv /tmp/flatten/#{jar_new} /usr/local/hbase/lib"
  end
end

script "clean_up_new_hadoop_jars_tmp_directory" do
  interpreter "bash"
  user "root"
  code <<-EOH
  rm -rf /tmp/hadoop
  rm -rf /tmp/flatten
  EOH
end

log "complete_14" do
  message "<AN_TRAN> STEP 14: Replace Hadoop bundled JARs in HBase lib with latest version completed"
  level :info
end


# Step 15: (Master only) Download Wikipedia sample pagecounts data

if node[:opsworks][:instance][:hostname] == "master"

  log "start_15" do
    message "<AN_TRAN> STEP 15: (Master only) Download Wikipedia sample pagecounts data started"
    level :info
  end

  script "download_wikipedia_pagecounts_data" do
    interpreter "bash"
    user "root"
    cwd "/home/hduser"
    code <<-EOH
    wget http://dumps.wikimedia.org/other/pagecounts-raw/2014/2014-01/pagecounts-20140107-160000.gz
    gzip -d pagecounts-20140107-160000.gz
    mv pagecounts-20140107-160000 pagecounts
    EOH
  end

  log "complete_15" do
    message "<AN_TRAN> STEP 15: (Master only) Download Wikipedia sample pagecounts data completed"
    level :info
  end

else

  log "pagecounts_data_not_master" do
    message "<AN_TRAN> STEP 15: (Master only) Download Wikipedia sample pagecounts data - This is not a master node, do nothing"
    level :info
  end

end
