require 'chefspec'

describe 'connect::suse_connect' do
  let(:chef_run) { ChefSpec::Runner.new.converge 'connect::suse_connect' }

  it 'clones connect github repo' do
    expect(chef_run).to sync_git('/tmp/connect').with(
      repository: 'https://github.com/SUSE/connect.git',
      reference: 'master'
    )
  end

  it 'installs required gems' do
    expect(chef_run).to run_execute('sudo bundle install').with(
      command: 'sudo bundle install',
      cwd: '/tmp/connect'
    )
  end

  it 'builds SUSEConnect gem from source' do
    expect(chef_run).to run_execute('build SUSEConnect gem').with(
      command: 'gem build suse-connect.gemspec',
      cwd: '/tmp/connect'
    )
  end

  # NOTE: Disabled because of RPM testing
  # it 'installs SUSEConnect gem' do
  #   expect(chef_run).to run_execute('install SUSEConnect gem').with(
  #     command: 'gem install suse-connect-*',
  #     cwd: '/tmp/connect'
  #   )
  # end

  it 'builds SUSEConnect RPM' do
    python_path = '$PYTHONPATH:/usr/lib64/python2.6/site-packages/'
    osc_build = 'osc -A https://api.suse.de build SLE_12 x86_64 --no-verify'

    expect(chef_run).to run_execute('build SUSEConnect RPM').with(
      command: "export PYTHONPATH=#{python_path}; echo 2|#{osc_build}",
      cwd: '/tmp/connect/package'
    )
  end

  it 'installs SUSEConnect RPM' do
    zypper_options = '--non-interactive  --no-gpg-checks'
    expect(chef_run).to run_execute('install SUSEConnect RPM').with(
      command: "zypper #{zypper_options} in /var/tmp/build-root/SLE_12-x86_64/home/abuild/rpmbuild/RPMS/x86_64/*",
      cwd: '/tmp/connect/package'
    )
  end
end
