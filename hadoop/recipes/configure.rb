# Step 1: Configure list of Hadoop Slave Nodes

log "start_1" do
  message "<AN_TRAN> STEP 1: Configure list of Hadoop Slave Nodes started"
  level :info
end

# Get the list of node names for master and slaves
masters = {}
slaves = {}

node[:opsworks][:layers][:hadoop][:instances].each do |instance_name, instance|
  if (instance_name =~ /master*/) != nil
    masters[instance[:private_ip]] = instance_name
  else
    slaves[instance[:private_ip]] = instance_name
  end
end

template "/usr/local/hadoop/etc/hadoop/slaves" do
  owner "hduser"
  group "hadoop"
  mode "0644"
  source "slaves.erb"
  variables({
    :masters => masters,
    :slaves => slaves
  })
end

log "complete_1" do
  message "<AN_TRAN> STEP 1: Configure list of Hadoop Slave Nodes completed"
  level :info
end


# Step 2: Update dfs.replication to match the number of instances in cluster

log "start_2" do
  message "<AN_TRAN> STEP 2: Update dfs.replication to match the number of instances in cluster started"
  level :info
end

# Get number of nodes in cluster
dfsReplication = 0

node[:opsworks][:layers][:hadoop][:instances].each do |instance_name, instance|
  dfsReplication = dfsReplication + 1
end

# Update the dfs.replication field in hdfs-site.xml file
if node[:opsworks][:instance][:hostname] == "master"

  template "/usr/local/hadoop/etc/hadoop/hdfs-site.xml" do
    owner "hduser"
    group "hadoop"
    mode "0644"
    source "master.hdfs-site.xml.erb"
    variables({
      :dfsReplication => dfsReplication
    })
  end
  
else

  template "/usr/local/hadoop/etc/hadoop/hdfs-site.xml" do
    owner "hduser"
    group "hadoop"
    mode "0644"
    source "slave.hdfs-site.xml.erb"
    variables({
      :dfsReplication => dfsReplication
    })
  end

end

log "complete_2" do
  message "<AN_TRAN> STEP 2: Update dfs.replication to match the number of instances in cluster completed"
  level :info
end


# Step 3: (Master only) Enable passwordless SSH login from Master Node to all Slave Nodes

if node[:opsworks][:instance][:hostname] == "master"

  log "start_3" do
    message "<AN_TRAN> STEP 3: (Master only) Enable passwordless SSH login from Master Node to all Slave Nodes started"
    level :info
  end

  # Gets list of names from all nodes managed by Chef Server
  hosts = {}

  node[:opsworks][:layers][:hadoop][:instances].each do |instance_name, instance|
    hosts[instance[:private_ip]] = instance_name
  end

  # Copy public key to all masters and slaves; if key doesn't exist in authorized_keys, append it to this file
  hosts.keys.sort.each do |ip|
    script "copy_ssh_keys_#{ip}" do
      interpreter "bash"
      user "hduser"
      code <<-EOH
        sshpass -p "password" scp -o StrictHostKeyChecking=no /home/hduser/.ssh/id_rsa.pub hduser@#{hosts[ip]}:/tmp
        sshpass -p "password" ssh -o StrictHostKeyChecking=no hduser@#{hosts[ip]} "(mkdir -p .ssh; touch .ssh/authorized_keys; grep #{node[:opsworks][:instance][:private_dns_name]} .ssh/authorized_keys > /dev/null || cat /tmp/id_rsa.pub >> .ssh/authorized_keys; rm /tmp/id_rsa.pub)"
      EOH
    end
  end

  log "complete_3" do
    message "<AN_TRAN> STEP 3: (Master only) Enable passwordless SSH login from Master Node to all Slave Nodes completed"
    level :info
  end

else

  log "not_master" do
    message "<AN_TRAN> STEP 3: (Master only) Enable passwordless SSH login from Master Node to all Slave Nodes - This is not a master node, do nothing"
    level :info
  end
  
end
