require 'rubygems'
require 'lookout/statsd'

module Elementary
  module Middleware
    class Statsd
      # Create a new Statsd middleware for Elementary
      #
      # @param [Hash] opts Hash of optional parameters
      # @option opts [Lookout::StatsdClient] :client Set to an existing instance of
      # a +Lookout::StatsdClient+ or other object implementing Statsd interface.
      def initialize(app, opts={})
        @app = app

        @statsd = opts[:client] || Lookout::StatsdClient.new
      end

      def call(service, rpc_method, *params)
        @statsd.timing(metric_name(service.name, rpc_method.method)) do
          @app.call(service, rpc_method, *params)
        end
      end

      def metric_name(service_name, method_name)
        service_name = service_name.gsub('::', '.').downcase
        return "elementary.#{service_name}.#{method_name}"
      end
    end
  end
end
