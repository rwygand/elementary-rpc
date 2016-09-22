require 'rubygems'
require 'cgi'
require 'faraday'
require 'socket'
require 'elementary/errors'
require 'elementary/future'

module Elementary
  module Transport
    class HTTP
      CONTENT_TYPE_HEADER = 'Content-Type'.freeze
      CONTENT_TYPE = 'application/x-protobuf'.freeze

      # Create a HTTP transport object for sending protobuf objects to the
      # service host names enumerated in +hosts+
      #
      # @param [Array] hosts A collection of host declarations ({:host => '',
      #   :port => 0, :prefix => '/'})
      # @param [Hash] opts Options to be passed directly into Faraday.
      def initialize(hosts, opts={})
        @hosts = hosts
        @options = Hashie::Mash.new({:logging => true, :logger => nil}).merge(opts)
        # Create connection here to avoid threading issues later. See Issue #43
        client
      end

      def call(service, rpc_method, *params)

        begin
          response = client.post do |h|
            path = "#{CGI.escape(service.name)}/#{rpc_method.method}"
            h.url(path)
            h.headers[CONTENT_TYPE_HEADER] = CONTENT_TYPE
            h.body = params[0].encode
          end

          return rpc_method[:response_type].decode(response.body)
        rescue StandardError => e
          raise e.exception("#{service.name}##{rpc_method.method}: #{e.message}")
        end
      end

      private

      def host_url
        # XXX: need to support a full collection of hosts similar to
        # elasticsearch-ruby
        host = @hosts.first
        prefix = host[:prefix]
        protocol = host[:protocol] || 'http'

        return "#{protocol}://#{host[:host]}:#{host[:port]}/#{prefix}"
      end

      def client
        return @client if @client

        faraday_middleware = @options.delete(:faraday_middleware) || []
        faraday_options = @options.merge({:url => host_url})
        logging = faraday_options.delete(:logging)
        logger = faraday_options.delete(:logger)

        @client = Faraday.new(faraday_options) do |f|
          f.request :raise_on_status
          f.response :logger, logger if logging
          f.adapter :httpclient
        end

        # Adapters aren't middleware, so we have to pop the adapter off before
        # we insert new middleware.  See:
        # https://github.com/lostisland/faraday/issues/375,
        # https://github.com/lostisland/faraday/issues/47
        adapter = @client.builder.handlers.pop
        faraday_middleware.each do |klass, *args|
          @client.use klass, *args
        end
        @client.builder.handlers << adapter

        return @client
      end
    end
  end
end
