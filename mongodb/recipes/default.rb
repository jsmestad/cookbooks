#
# Cookbook Name:: mongodb
# Recipe:: default

gem_package "right_aws"
include_recipe "aws"
include_recipe "xfs"

# Add 10gen to the repo list so we can install the package
remote_file "/etc/apt/sources.list.d/10gen.list" do
  source "10gen.list"
  owner "root"
  group "root"
  mode  0644
end

# # add the key to apt, and update the repositories
# remote_file "/tmp/10gen.key" do
#   source "10gen.key"
# end
# execute "apt-key add /tmp/10gen.key"
execute "apt-get update"

package "mongodb-stable" do
  # 10gen's key isn't acutally correct.
  options "--force-yes"
end

ebs = node[:mongodb][:ebs]
access_key = node[:aws][:access_key]
secret_access_key = node[:aws][:secret_access_key]

directory node[:mongodb][:data_dir] do
  recursive true
  owner "mongodb"
  group "mongodb"
end

if ebs[:raid] 

  ebs[:raid_volumes].times do |i|
    aws_ebs_volume "data_volume #{i+1}" do
      provider "aws_ebs_volume"

      size                  ebs[:size]
      device                "#{ebs[:device]}#{i+1}"

      aws_access_key        access_key
      aws_secret_access_key secret_access_key

      action [:create, :attach]
    end
  end

  mdadm "/dev/md0" do
    devices ebs[:raid_volumes].times.map { |i| "#{ebs[:device]}#{i+1}" }
    level 0
    chunk 64
    action [ :create, :assemble ]
  end

  execute "make ebs filesystem" do
    command "mkfs.xfs /dev/md0"
    not_if "file -s /dev/md0 | grep -i XFS"
  end

  mount node[:mongodb][:data_dir] do
    device "/dev/md0"
    fstype "xfs"
    options "rw noatime"
    action [:enable, :mount]
  end

else

  aws_ebs_volume ebs[:device] do
    provider "aws_ebs_volume"

    size                  ebs[:size]
    device                ebs[:device]

    aws_access_key        access_key
    aws_secret_access_key secret_access_key

    action [:create, :attach]
  end

  execute "make ebs filesystem" do
    command "mkfs.xfs #{ebs[:device]}"
    not_if "file -s #{ebs[:device]} | grep -i XFS"
  end

  mount node[:mongodb][:data_dir] do
    device ebs[:device]
    fstype "xfs"
    options "rw noatime"
    action [:enable, :mount]
  end

end

execute "fix perms" do
  command "chown mongodb:mongodb #{node[:mongodb][:data_dir]}"
  not_if %Q{ stat -c "%U" #{node[:mongodb][:data_dir]} | grep mongodb }
end

service "mongodb"

template "/etc/mongodb.conf" do
  source "mongodb.conf.erb"
  notifies :restart, resources(:service => "mongodb")
end

