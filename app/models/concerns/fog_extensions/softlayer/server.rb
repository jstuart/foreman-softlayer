module FogExtensions
  module Softlayer
    module Server
      extend ActiveSupport::Concern
      
      attr_accessor :use_image
      attr_accessor :prov_network_speed
      attr_accessor :prov_os_code
      attr_accessor :prov_disk_0
      # Disk 1 is always swap
      attr_accessor :prov_disk_2
      attr_accessor :prov_disk_3
      attr_accessor :prov_disk_4
      attr_accessor :prov_disk_5
      
      # Do some magic to ditch the Server#vlan method which doesn't work right
      def self.append_features(mod)
        # Iterate through all of the methods, ignoring superclasses
        # which is what all of the methods here would be...
        instance_methods(false).each { |method|
          if (method.to_s == 'vlan')
            mod.send(:remove_method, method)
          end
        }
        super
      end
      
      def identity_to_s
        identity.to_s
      end

      def vm_description
        "DC: #{datacenter}; CPU: #{cpu}; Memory: #{ram}"
      end
      
      def server_type
        (:bare_metal == true ? 'Physical' : 'Virtual')
      end

      def region
        :datacenter
      end

      def region_name
        :datacenter.long_name
      end
            
      def prov_network_speed
        if network_components
          enabled = network_components.select { |nc|
            nc.status == 'ACTIVE'
          }
          if enabled && enabled.first
            enabled.first.max_speed
          else
            @prov_network_speed
          end
        else
          @prov_network_speed
        end
      end
      
      def prov_os_code
        if os_code && os_code != ''
          os_code
        else
          @prov_os_code
        end
      end
      
      def prov_disk_0
        @disk_prov_0 ||= get_prov_disk_size(0)
      end
      
      # Disk 1 is swap
      
      def prov_disk_2
        @disk_prov_2 ||= get_prov_disk_size(2)
      end
      
      def prov_disk_3
        @disk_prov_3 ||= get_prov_disk_size(3)
      end
      
      def prov_disk_4
        @disk_prov_4 ||= get_prov_disk_size(4)
      end
      
      def prov_disk_5
        @disk_prov_5 ||= get_prov_disk_size(5)
      end

      def ip_addresses
        [private_ip_address, public_ip_address].flatten.select(&:present?)
      end

      # We're going to produce string IDs when using forms, so force those to int.
      def private_vlan=(value)
        if value.is_a(String)
          value = value.to_i
        end
        super(value)
      end
      
      # Override vlan so we can catch and ignore the exception that is thrown when a public adapter isn't present
      def vlan
        # FIXME this needs to be fixed in fog-softlayer
        attributes[:vlan] ||= (_get_vlan rescue nil)
      end

      # We're going to produce string IDs when using forms, so force those to int.
      def vlan=(value)
        if value.is_a(String)
          value = value.to_i
        end
        super(value)
      end

      def create_vm(args = {})
        super(args)
      rescue Fog::Errors::Error => e
        logger.error "Unhandled Softlayer error: #{e.class}:#{e.message}\n " + e.backtrace.join("\n ")
      end 
      
      private
      
      def get_prov_disk_size(number)
        if (disk && disk.is_a?(Array))
          drive = disk.select{ |d|  d['device'] == "#{number}"}.first
          if (drive)
            # FIXME fog-softlayer update needed
            # Disk size doesn't come back right now...
          end
        end
      end
    end
  end
end

