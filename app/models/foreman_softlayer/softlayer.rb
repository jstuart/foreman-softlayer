module ForemanSoftlayer
  class Softlayer < ComputeResource
    validates :user, :password, :presence => true
    validates :url, :format => { :with => URI.regexp }
    
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
        args.each { |k,v|
          # Modify vlan attrs
          if ('vlan' == k || 'private_vlan' == k)
            # If it's empty, just remove it
            if ('' == v)
              args.delete(k)
            # If it's a string, make it an int
            elsif (v.is_a?(String))
              args[k] = v.to_i
            end
          end
        }
      end
      #super(args)
    rescue Fog::Errors::Error => e
      logger.error "Unhandled Softlayer error: #{e.class}:#{e.message}\n " + e.backtrace.join("\n ")
      raise e
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
      @vm_opts_disk_0 ||= devices = vm_create_opts['blockDevices'].select { |item|
        item['template']['blockDevices'].first['device'] == '0'
      }.map { |item|
        item['template']['blockDevices'].first['diskImage']['capacity']
      }.uniq.sort
    end
    
    def vm_opts_disk_1
      @vm_opts_disk_1 ||= devices = vm_create_opts['blockDevices'].select { |item|
        item['template']['blockDevices'].first['device'] == '1'
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
    
    # Need to add some data here...
    #def vm_instance_defaults
    #  super.merge(
    #  )
    #end

  end
end

