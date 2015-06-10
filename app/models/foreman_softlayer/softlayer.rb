module ForemanSoftlayer
  class Softlayer < ComputeResource
    has_one :key_pair, :foreign_key => :compute_resource_id, :dependent => :destroy
    
    validates :user, :password, :presence => true
    validates :url, :format => { :with => URI.regexp }
      
    after_create :setup_key_pair
    after_destroy :destroy_key_pair
    
    before_create :test_connection

    def to_label
      "#{name} (#{provider_friendly_name})"
    end
    
    def provided_attributes
      super.merge({ :uuid => :identity_to_s, :ip => :private_ip_address })
    end

    def self.model_name
      ComputeResource.model_name
    end

    def capabilities
      [:image]
    end
    
    # return a list of virtual machines
    def vms(opts = {})
      client.servers
    end
    
    def find_vm_by_uuid(uuid)
      client.servers.get(uuid)
    rescue Fog::Compute::Softlayer::Error
      raise(ActiveRecord::RecordNotFound)
    end

    def create_vm(args = {})
      
      if args && args.is_a?(Hash)
        # Merge
        args = vm_instance_defaults.merge(args.to_hash.deep_symbolize_keys)
        
        # Swap some args
        
        # Move the OS code to the appropriate location
        if (args.key?('prov_os_code'))
          if ('' != args['prov_os_code'])
            args['os_code'] = args['prov_os_code']
          end
          args.delete('prov_os_code')
        end

        # Remove the OS code if we're using images, otherwise remove the image_id
        if (args.key?('use_image'))
          if ("1" == args['use_image'] && args.key?('image_id') && '' != args['image_id'])
            if (args.key?('os_code'))
              args.delete('os_code')
            end
          else
            if (args.key?('image_id'))
              args.delete('image_id')
            end
          end
          args.delete('use_image')
        end
        
        # Split out domain which is required separately
        if (args.key?('name'))
          parts = args['name'].split('.')
          args['name'] = parts.shift
          args['domain'] = parts.join('.')
        end
        
        # VLAN to int
        if (args.key?('vlan'))
          if ('' == args['vlan'])
            # If empty, delete
            args.delete('vlan')
          elsif (args['vlan'].is_a?(String))
            # Otherwise convert to an int
            args['vlan'] = args['vlan'].to_i
          end
        end

        # Private VLAN to int
        if (args.key?('private_vlan'))
          if ('' == args['private_vlan'])
            # If empty, delete
            args.delete('private_vlan')
          elsif (args['private_vlan'].is_a?(String))
            # Otherwise convert to an int
            args['private_vlan'] = args['private_vlan'].to_i
          end
        end
        
        # Move the network speed to the appropriate location
        if (args.key?('prov_network_speed'))
          if ('' != args['prov_network_speed'])
            if (args['network_components'])
              if (args['network_components'].is_a?(Array))
                if (args['network_components'].length > 0)
                  args['network_components'].first['speed'] = args['prov_network_speed'].to_i
                else
                  args['network_components'].push({'speed' => args['prov_network_speed'].to_i})
                end
              else
                # FIXME die here?
                logger.warn "The type of the Softlayer 'network_components' is unsupported: #{args['network_components'].class} ; valid types are nil or Array"
              end
            else
              args['network_components'] = [{'speed' => args['prov_network_speed'].to_i}]
            end
          end
          args.delete('prov_network_speed')
        end
        
        # Fix the disks param
        if (!args.key?('disk'))
          args['disk'] = []
        end
        
        # Add disks
        if (args['disk'].is_a?(Array))
          if (args.key?('prov_disk_0'))
            if ('' != args['prov_disk_0'])
              args['disk'].push({'device' => 0, 'diskImage' => {'capacity' => args['prov_disk_0'].to_i}})
            end
            args.delete('prov_disk_0')
          end
          
          if (args.key?('prov_disk_2'))
            if ('' != args['prov_disk_2'])
              args['disk'].push({'device' => 2, 'diskImage' => {'capacity' => args['prov_disk_2'].to_i}})
            end
            args.delete('prov_disk_2')
          end
        else
          # FIXME die here?
          logger.warn "The type of the Softlayer 'disk' is unsupported: #{args['disk'].class} ; valid types are nil or Array"
        end
        
        # Add any new attributes
        if (args.key?('key_pairs'))
          if (args['key_pairs'].is_a?(Array))
            args['key_pairs'].push(primary_key_pair)
          else
            # FIXME die here?
            logger.warn "The type of the Softlayer 'key_pairs' is unsupported: #{args['key_pairs'].class} ; valid types are nil or Array"
          end
        else
          args['key_pairs'] = [client.key_pairs.by_label(key_pair.name)]
        end
      end

      super(args)
    rescue Fog::Errors::Error => e
      logger.error "Unhandled Softlayer error: #{e.class}:#{e.message}\n " + e.backtrace.join("\n ")
      raise e
    end
    
    def all_key_pairs
      @all_key_pairs ||= client.key_pairs.all
    end

    def available_images
      client.images
    end

    def regions
      return [] if user.blank? || password.blank?
      net_client.datacenters.map { |dc| dc.name.upcase }
    end
    
    def ensure_valid_region
      unless regions.include?(region.upcase)
        errors.add(:region, 'is not valid')
      end
    end

    def test_connection(options = {})
      super
      errors[:user].empty? and errors[:password].empty? and regions.count
    rescue Excon::Errors::Unauthorized => e
      errors[:base] << e.response.body
    rescue Fog::Errors::Error => e
      errors[:base] << e.message
    end

    def destroy_vm(uuid)
      vm = find_vm_by_uuid(uuid)
      vm.destroy if vm.present?
      true
    end

    # not supporting update at the moment
    def update_required?(old_attrs, new_attrs)
      false
    end
    
    def self.provider_friendly_name
      "Softlayer"
    end

    def associated_host(vm)
      associate_by("ip", [vm.public_ip_address, vm.private_ip_address])
    end

    def user_data_supported?
      true
    end

    def default_region_name
      @default_region_name ||= net_client.datacenters.get(region.to_i).try(:name)
    rescue Excon::Errors::Unauthorized => e
      errors[:base] << e.response.body
    end
    
    def vm_opts_datacenters
      @vm_opts_datacenters ||= vm_create_opts['datacenters'].map { |dc|
        dc['template']['datacenter']['name'] 
      }.sort.uniq
    end
    
    def vm_opts_disk_0
      @vm_opts_disk_0 ||= vm_create_opts['blockDevices'].select { |item|
        item['template']['blockDevices'].first['device'] == '0'
      }.map { |item|
        item['template']['blockDevices'].first['diskImage']['capacity']
      }.uniq.sort
    end
    
    def vm_opts_disk_2
      @vm_opts_disk_2 ||= vm_create_opts['blockDevices'].select { |item|
        item['template']['blockDevices'].first['device'] == '2'
      }.map { |item|
        item['template']['blockDevices'].first['diskImage']['capacity']
      }.uniq.sort
    end
    
    def vm_opts_memory
      @vm_opts_memory ||= vm_create_opts['memory'].map { |item|
        item['template']['maxMemory']
      }.sort.uniq
    end
    
    def vm_opts_os
      @vm_opts_os ||= vm_create_opts['operatingSystems'].map { |item|
        item['template']['operatingSystemReferenceCode']
      }.sort.uniq
    end
    
    def vm_opts_cpu
      @vm_opts_cpu ||= vm_create_opts['processors'].map { |item|
        item['template']['startCpus']
      }.sort.uniq
    end
    
    def vm_opts_net
      @vm_opts_net ||= vm_create_opts['networkComponents'].map { |item|
        item['template']['networkComponents'].first['maxSpeed']
      }.sort.uniq
    end
    
    def public_vlans
      @public_vlans ||= vlans.select { |vlan|
        vlan.private? == false
      }
    end

    def private_vlans
      @private_vlans ||= vlans.select { |vlan|
        vlan.private? == true
      }
    end

    private

    def client
      @client ||= Fog::Compute.new(
        :provider => "softlayer",
        :softlayer_username => user,
        :softlayer_api_key => password
      )
    end
    
    def net_client
      @net_client ||= Fog::Network.new(
        :provider => "softlayer",
        :softlayer_username => user,
        :softlayer_api_key => password
      )
    end
    
    def vm_create_opts
      @vm_create_opts ||= client.servers.get_vm_create_options
    rescue Fog::Errors::Error => e
      errors[:base] << e.message
    end
    
    def vlans
      @vlans ||= net_client.networks
    rescue Fog::Errors::Error => e
      errors[:base] << e.message
    end
    
    def primary_key_pair
      @primary_key_pair ||= client.key_pairs.by_label(key_pair.name)
    end
    
    # Key generation borrowed from the foreman-digitalocean module
    def setup_key_pair
      public_key, private_key = generate_key
      key = client.key_pairs.create(:label => "foreman-#{id}#{Foreman.uuid}", :key => public_key)
      KeyPair.create! :name => key.name, :compute_resource_id => self.id, :secret => private_key
    rescue => e
      logger.warn "failed to generate key pair"
      logger.error e.message
      logger.error e.backtrace.join("\n")
      destroy_key_pair
      raise
    end
    
    def destroy_key_pair
      return unless key_pair
      logger.info "removing Softlayer key #{key_pair.name}"
      key = client.key_pairs.by_label(key_pair.name)
      key.destroy if key
      key_pair.destroy
      true
    rescue => e
      logger.warn "failed to delete key pair from Softlayer, you might need to cleanup manually : #{e}"
    end
    
    def generate_key
      key = OpenSSL::PKey::RSA.new 2048
      type = key.ssh_type
      data = [ key.to_blob ].pack('m0')
    
      openssh_format_public_key = "#{type} #{data}"
      [openssh_format_public_key, key.to_pem]
    end
    
    def vm_instance_defaults
      super.merge(
        :key_pair  => key_pair
      )
    end

  end
end

