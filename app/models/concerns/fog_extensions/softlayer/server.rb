module FogExtensions
  module Softlayer
    module Server
      extend ActiveSupport::Concern
      
      attr_accessor :prov_network_speed
      attr_accessor :prov_os_code
      
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

      # We're going to produce string IDs when using forms, so force those to int.
      def vlan=(value)
        if value.is_a(String)
          value = value.to_i
        end
        super(value)
      end
            
    end
  end
end

