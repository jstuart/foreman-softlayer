module FogExtensions
  module Softlayer
    module KeyPair
      extend ActiveSupport::Concern
   
      # alias name to label
      def name label
        label(label)
      end
      
      # alias name to label
      def name
        label
      end
    end
  end
end