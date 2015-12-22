#
# Cookbook Name:: ossec
# Recipe:: client
#
# Copyright 2010, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ossec_server = Array.new

search_string = "role:#{node['ossec']['server_role']}"
search_string << " AND chef_environment:#{node['ossec']['server_env']}" if node['ossec']['server_env']

if node.run_list.roles.include?(node['ossec']['server_role'])
  ossec_server << node['ipaddress']
else
  search(:node, search_string) do |n|
    ossec_server << n['ipaddress']
  end
end

node.set['ossec']['user']['install_type'] = "agent"
node.set['ossec']['user']['agent_server_ip'] = ossec_server.first

include_recipe "ossec"

dbag_name = node["ossec"]["data_bag"]["name"]
dbag_item = node["ossec"]["data_bag"]["ssh"]
if node["ossec"]["data_bag"]["encrypted"]
  if node['ossec']['data_bag']['use_vault']
    include_recipe 'chef-vault'
    ossec_key = ChefVault::Item.load(dbag_name, dbag_item)
  else
    ossec_key = Chef::EncryptedDataBagItem.load(dbag_name, dbag_item)
  end
else
  ossec_key = data_bag_item(dbag_name, dbag_item)
end

user "ossecd" do
  comment "OSSEC Distributor"
  shell "/bin/bash"
  system true
  gid "ossec"
  home node['ossec']['user']['dir']
end

directory "#{node['ossec']['user']['dir']}/.ssh" do
  owner "ossecd"
  group "ossec"
  mode 0750
end

template "#{node['ossec']['user']['dir']}/.ssh/authorized_keys" do
  source "ssh_key.erb"
  owner "ossecd"
  group "ossec"
  mode 0600
  variables(:key => ossec_key['pubkey'])
end

file "#{node['ossec']['user']['dir']}/etc/client.keys" do
  owner "ossecd"
  group "ossec"
  mode 0660
end
