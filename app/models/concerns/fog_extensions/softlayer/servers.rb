module FogExtensions
  module Softlayer
    module Servers
      extend ActiveSupport::Concern

      # Do some magic to ditch the Servers#all method which doesn't accept params
      def self.append_features(mod)
        # Iterate through all of the methods, ignoring superclasses
        # which is what all of the methods here would be...
        instance_methods(false).each { |method|
          if (method.to_s == 'all')
            mod.send(:remove_method, method)
          end
        }
        super
      end
      
      def all(filters = {})
        data = service.list_servers
        load(data)
      end
      
      def create(attributes = {})
        super(convert_vlan(attributes))
      end
      
      def new(attributes = {})
        super(convert_vlan(attributes))
      end
      
      private
      
      def convert_vlan(attributes = {})
        if attributes && attributes.is_a?(Hash)
          attributes.each { |k,v|
            # Modify vlan attrs
            if ('vlan' == k || 'private_vlan' == k)
              # If it's empty, just remove it
              if ('' == v)
                attributes.delete(k)
              # If it's a string, make it an int
              elsif (v.is_a?(String))
                attributes[k] = v.to_i
              end
            end
          }
        end
        attributes
      end
            
    end
  end
end

