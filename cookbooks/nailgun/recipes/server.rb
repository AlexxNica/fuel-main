node.set[:django][:venv] = node.nailgun.venv
include_recipe 'django'

# FIXME
# it is nice to encapsulate all these components into os package
# installing deps, creating system user, installing nailgun files

include_recipe 'nailgun::deps'

group node.nailgun.group do
  action :create
end

user node.nailgun.user do
  home node.nailgun.root
  gid node.nailgun.group
  system true
end

directory node.nailgun.root do
  user node.nailgun.user
  group node.nailgun.group
  mode '775'
end

directory "/var/log/nailgun" do
  owner node.nailgun.user
  group node.nailgun.group
  mode '775'
  recursive true
end

template "#{node.nailgun.root}/nailgun/extrasettings.py" do
  source 'extrasettings.py.erb'
  owner node.nailgun.user
  group node.nailgun.group
  mode '664'
  variables(
            :level => "DEBUG",
            :filename => "/var/log/nailgun/nailgun.log",
            :sshkey => "#{node.nailgun.root}/.ssh/id_rsa"
            )
end

ssh_keygen "Nailgun ssh-keygen" do
  homedir node.nailgun.root
  username node.nailgun.user
  groupname node.nailgun.group
  keytype 'rsa'
end

file "#{node[:nailgun][:root]}/nailgun/venv.py" do
  content "VENV = '#{node[:nailgun][:venv]}/local/lib/python2.7/site-packages'
"
  owner node.nailgun.user
  group node.nailgun.group
  mode '664'
end

# it is assumed that nailgun files already installed into nailgun.root
execute 'chown nailgun root' do
  command "chown -R #{node[:nailgun][:user]}:#{node[:nailgun][:group]} #{node[:nailgun][:root]}"
end

execute 'chmod nailgun root' do
  command "chmod -R ug+w #{node[:nailgun][:root]}"
end

# execute 'Preseed Nailgun database' do
#   command "#{node[:nailgun][:python]} manage.py loaddata nailgun/fixtures/default_env.json"
#   cwd node.nailgun.root
#   user node.nailgun.user
#   action :nothing
# end

execute 'Sync Nailgun database' do
  command "#{node[:nailgun][:python]} manage.py syncdb --noinput"
  cwd node.nailgun.root
  user node.nailgun.user
  # notifies :run, resources('execute[Preseed Nailgun database]')
  not_if "test -e #{node[:nailgun][:root]}/nailgun.sqlite"
end

redis_instance 'nailgun'

celery_instance 'nailgun-jobserver' do
  command "#{node[:nailgun][:python]} manage.py celeryd_multi start Worker -E"
  cwd node.nailgun.root
  events true
  user node.nailgun.user
  virtualenv node.nailgun.venv
end

web_app 'nailgun' do
  template 'apache2-site.conf.erb'
end

