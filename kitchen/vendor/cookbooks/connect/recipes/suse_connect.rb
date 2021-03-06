git '/tmp/connect' do
  repository 'https://github.com/SUSE/connect.git'
  reference 'master'
  action 'sync'
  user 'vagrant'
  group 'users'
end

execute 'sudo bundle install' do
  command 'sudo bundle install'
  cwd node[:connect][:project]
  user 'vagrant'
  group 'users'
end

execute 'build SUSEConnect gem' do
  command 'gem build suse-connect.gemspec'
  cwd node[:connect][:project]
  user 'vagrant'
  group 'users'
end

# NOTE: Disabled because of RPM testing
# execute 'install SUSEConnect gem' do
#   command 'gem install suse-connect-*'
#   cwd node[:connect][:project]
# end

execute 'cp suse-connect-*.gem package/' do
  command 'cp suse-connect-*.gem package/'
  cwd node[:connect][:project]
  user 'vagrant'
end

execute 'gem2rpm -l -o SUSEConnect.spec -t SUSEConnect.spec.erb suse-connect-*.gem' do
  command 'gem2rpm -l -o SUSEConnect.spec -t SUSEConnect.spec.erb suse-connect-*.gem'
  cwd "#{node[:connect][:project]}/package"
  user 'vagrant'
end

execute 'create man page for SUSEConnect' do
  command 'ronn --roff --manual SUSEConnect --pipe ../README.md > SUSEConnect.1 && gzip SUSEConnect.1'
  not_if { ::File.exist?('/tmp/connect/package/SUSEConnect.1.gz') }
  cwd "#{node[:connect][:project]}/package"
  user 'vagrant'
end

python_path = '$PYTHONPATH:/usr/lib64/python2.6/site-packages/'
osc_url = 'https://api.suse.de'
osc_build = "osc -A #{osc_url} build #{node[:connect][:osc][:project]} #{node[:connect][:osc][:arch]} --no-verify"

execute 'build SUSEConnect RPM' do
  command "export PYTHONPATH=#{python_path}; echo 2|#{osc_build}"
  cwd "#{node[:connect][:project]}/package"
end

zypper_options = '--non-interactive  --no-gpg-checks'
execute 'install SUSEConnect RPM' do
  command "zypper #{zypper_options} in /var/tmp/build-root/SLE_12-x86_64/home/abuild/rpmbuild/RPMS/x86_64/*"
  cwd "#{node[:connect][:project]}/package"
end
