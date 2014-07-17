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
  wget http://www.interior-dsgn.com/apache/hadoop/common/hadoop-#{node[:Hadoop][:Core][:version]}/hadoop-#{node[:Hadoop][:Core][:version]}.tar.gz
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
    wget http://d3kbcqa49mib13.cloudfront.net/spark-1.0.1-bin-hadoop2.tgz
    tar -xf spark-1.0.1-bin-hadoop2.tgz -C /usr/local
    ln -s /usr/local/spark-1.0.1-bin-hadoop2 /usr/local/spark
    chown -R hduser:hadoop /usr/local/spark-1.0.1-bin-hadoop2
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