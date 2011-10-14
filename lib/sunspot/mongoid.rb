require 'sunspot'
require 'mongoid'
require 'sunspot/rails'

# == Examples:
#
# class Post
#   include Mongoid::Document
#   field :title
# 
#   include Sunspot::Mongoid
#   searchable do
#     text :title
#   end
# end
#
module Sunspot
  module Mongoid
    def self.included(base)
      base.class_eval do
        extend Sunspot::Rails::Searchable::ActsAsMethods
        Sunspot::Adapters::DataAccessor.register(DataAccessor, base)
        Sunspot::Adapters::InstanceAdapter.register(InstanceAdapter, base)
      end
    end

    class InstanceAdapter < Sunspot::Adapters::InstanceAdapter
      def id
        @instance.id
      end
    end

    class DataAccessor < Sunspot::Adapters::DataAccessor
      def load(id)
        criteria(BSON::ObjectId(id)).first
      end

      def load_all(ids)
        criteria(ids.map {|i| BSON::ObjectId(i)})
      end

      private

      def criteria(id)
        @clazz.find(id)
      end
    end
    
    
    class <<self
      attr_writer :configuration

      def configuration(path = nil)
        @configuration ||= Sunspot::Mongoid::Configuration.new(path)
      end

      def reset
        @configuration = nil
      end
      def build_session(configuration = self.configuration)
        if configuration.has_master?
          SessionProxy::MasterSlaveSessionProxy.new(
            SessionProxy::ThreadLocalSessionProxy.new(master_config(configuration)),
            SessionProxy::ThreadLocalSessionProxy.new(slave_config(configuration))
          )
        else
          SessionProxy::ThreadLocalSessionProxy.new(slave_config(configuration))
        end
      end
      private

      def master_config(sunspot_mongoid_configuration)
        config = Sunspot::Configuration.build
        config.solr.url = URI::HTTP.build(
          :host => sunspot_mongoid_configuration.master_hostname,
          :port => sunspot_mongoid_configuration.master_port,
          :path => sunspot_mongoid_configuration.master_path
        ).to_s
        config
      end

      def slave_config(sunspot_mongoid_configuration)
        config = Sunspot::Configuration.build
        config.solr.url = URI::HTTP.build(
          :host => sunspot_mongoid_configuration.hostname,
          :port => sunspot_mongoid_configuration.port,
          :path => sunspot_mongoid_configuration.path
        ).to_s
        config
      end
    end
  end
end
