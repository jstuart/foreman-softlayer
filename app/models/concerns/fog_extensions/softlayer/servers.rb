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
        # The commented code below will handle the conversion of an array of selected
        # key pair IDs into an array of actual keypairs.  It also breaks the ability to 
        # add key pairs on create.
        #
        #if (attributes.key?('key_pairs') && attributes['key_pairs'].is_a?(Array))
        #  # Resolve the key pairs in the array
        #  kp_array = []
        #  attributes['key_pairs'].map { |id|
        #    if (id && id.is_a?(String) && '' != id)
        #      kp = service.key_pairs.get(id)
        #      if (nil != kp)
        #        kp_array.push(kp)
        #        end
        #    end
        #  }
        #  attributes['key_pairs'] = kp_array
        #end
        super(convert_attrs(attributes))
      end
      
      def new(attributes = {})
        super(convert_attrs(attributes))
      end
      
      private
      
      def convert_attrs(attributes = {})
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

