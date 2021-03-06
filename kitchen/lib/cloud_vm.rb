require 'openstack'
require 'fileutils'
require 'yaml'

module Cloud
  # Access cloud.suse.de opentsack API
  class VM
    class << self
      def connection
        if ENV['CLOUD_USER'] && ENV['CLOUD_PASS']
          @connection ||= OpenStack::Connection.create(
            :username => ENV['CLOUD_USER'],
            :api_key => ENV['CLOUD_PASS'],
            :auth_method => 'password',
            :auth_url => 'https://dashboardp2.cloud.suse.de:5000/v2.0',
            :authtenant_name => 'appliances',
            :service_type => 'compute'
          )
        else
          puts 'ERROR: Environment variable CLOUD_USER or CLOUD_PASS is not defined'
          exit(1)
        end
      end

      def create(name = 'SUSEConnect_testing')
        image = connection.get_image('19724f29-9713-4277-b359-2029508acf16')
        flavor = connection.get_flavor(2)
        address = connection.get_floating_ips.select {|ip| ip.instance_id.nil? }.first || connection.create_floating_ip

        puts "*** Creating new '#{name}' VM ..."
        server = connection.create_server(:name => name, :imageRef => image.id, :flavorRef => flavor.id)

        attach_ip(server, address)

        # FIXME: Speed up testing, check with Net::SSH if machine is ready for provisioning
        delay = (ENV['TIME_WAIT'] || 10).to_i
        puts "*** Waiting #{delay} seconds for the machine to boot ..."
        sleep(delay)

        puts "*** Creating node configuration file #{address.ip}.json ..."
        create_node_file(address.ip)

        store_vm_info(server.id, name, address.ip)

        server
      end

      def destroy(name = 'SUSEConnect_testing')
        vm = connection.servers.find {|s| s[:name] == name }
        if vm
          vm = connection.get_server vm[:id]
          vm.delete!

          # Remove vm info file
          File.delete('vm_info.yml')
        else
          puts "ERROR: Cann't find VM with name '#{name}'"
          exit(1)
        end
      end

      # Deregister VM system
      def deregister!
        $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '../../lib'))
        require File.expand_path(File.join(File.dirname(__FILE__), '../../lib/suse/connect.rb'))
        SUSE::Connect::Client.new({}).deregister!
      end

      def attach_ip(server, address)
        puts "*** Attaching floating ip '#{address.ip}' to '#{server.name}' VM ..."
        connection.attach_floating_ip(:server_id => server.id, :ip_id => address.id)

        rescue OpenStack::Exception::BadRequest
          sleep 5
          attach_ip(server, address)

      end

      def create_node_file(ip)
        dir = File.join(File.expand_path(File.dirname(__FILE__)), '../nodes')
        src = File.join(dir, 'template.json')
        dest = File.join(dir, "#{ip}.json")
        FileUtils.cp(src, dest)
      end

      def store_vm_info(id, name, ip)
        File.open('vm_info.yml', 'w') {|f| YAML.dump({ vm: { id: id, name: name, ip: ip } }, f) }
      end
    end
  end
end
