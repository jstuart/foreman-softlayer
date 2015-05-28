# A wrapper class for the normal Softlayer Servers model
# which allows for filters to be passed and promptly discarded.
require 'fog/softlayer/models/compute/servers'
require 'delegate'

module FogExtensions
  module Softlayer
    class Servers < SimpleDelegator
      
      # Accept and ignore passed filters
      def all(filters)
        __getobj__.all
      end
      
    end
  end
end

