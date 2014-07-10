tomcat_pkgs = value_for_platform(
  ['debian', 'ubuntu'] => {
    'default' => ["tomcat#{node['tomcat']['old_version']}", 'libtcnative-1', 'libmysql-java']
  },
  ['centos', 'redhat', 'fedora', 'amazon'] => {
    'default' => ["tomcat#{node['tomcat']['old_version']}", 'tomcat-native', 'mysql-connector-java']
  },
  'default' => ["tomcat#{node['tomcat']['old_version']}"]
)

service 'tomcat' do
  service_name "tomcat#{node['tomcat']['old_version']}"
  action :stop
end

tomcat_pkgs.each do |pkg|
  package pkg do
    action :purge
  end
end

script "clean_apt_repo" do
  interpreter "bash"
  user "root"
  code <<-EOH
  sudo apt-get clean
  EOH
end
