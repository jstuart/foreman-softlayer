module FogExtensions
  module Softlayer
    module Server
      extend ActiveSupport::Concern

      def identity_to_s
        identity.to_s
      end

      def vm_description
        flavor.try(:name)
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

      def ip_addresses
        [private_ip_address, public_ip_address].flatten.select(&:present?)
      end

    end
  end
end

