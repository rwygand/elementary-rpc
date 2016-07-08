require 'faraday'

module Elementary
  module Middleware
    class HttpStatusError < StandardError
      attr_reader :status_code, :method, :url, :parent_message
      def initialize(opts = {})
        @status_code = opts.fetch(:status_code, nil)
        @method = opts.fetch(:method, "<Unknown Method>")
        @url = opts.fetch(:method, "<Unknown URL>")

        message = if connection_refused?
                    "#{method} #{url} returned a connection refused: #{opts.fetch(:parent_message, '<Unknown Message>')}"
                  else
                    "#{method} #{url} returned an HTTP response status of #{status_code}, so an exception was raised."
                  end
        super message
      end

      # We assume that the connection was refused if no status code was set.
      # @return [Boolean]
      def connection_refused?
        @status_code.nil?
      end
    end
    ##
    # Raise an exception for certain HTTP response status codes
    #
    # Examples
    #
    #   Faraday.new do |conn|
    #     conn.request :raise_on_status
    #     conn.adapter ...
    #   end
    #
    # The above example will raise an HttpStatusError if the response
    # contains a code in the range 300 through 600.
    #
    # You can also pair this with the retry middleware to attempt
    # to recover from intermittent failures...
    #
    #   Faraday.new do |conn|
    #     conn.request :retry, max: 2, interval: 0.05,
    #                          interval_randomness: 0.5, backoff_factor: 2
    #                          exceptions: [Faraday::TimeoutError, SecurityEvents::HttpStatusError]
    #     conn.request :raise_on_status
    #     conn.adapter ...
    #   end
    #
    # This example will do the same as the first, but the exception
    # will be caught by the retry middleware and the request will be
    # executed up to two more times before raising.
    # NOTE: Middleware order matters here!
    #
    class RaiseOnStatus < Faraday::Middleware

      DEFAULT_STATUS_ARRAY = [300..600]
      ERROR_HEADER_MSG = 'x-protobuf-error'
      ERROR_HEADER_CODE = 'x-protobuf-error-reason'

      dependency do
        require 'set'
      end

      # Public: Initialize middleware
      def initialize(app)
        super(app)
        status_array ||= DEFAULT_STATUS_ARRAY
        @status_set = status_option_array_to_set(status_array)
      end

      def call(request_env)
        begin
          @app.call(request_env).on_complete do |response_env|
            status = response_env[:status]
            if @status_set.include? status
              error_opts = {
                  :status_code => status,
                  :method => response_env.method.to_s.upcase,
                  :url => response_env.url.to_s
              }
              headers = response_env[:response_headers]
              if headers.include?(ERROR_HEADER_CODE) && headers.include?(ERROR_HEADER_MSG)
                error_opts[:header_message] = headers[ERROR_HEADER_MSG]
                error_opts[:header_code] = headers[ERROR_HEADER_CODE]
                raise Elementary::Errors::RPCFailure, error_opts
              else
                raise HttpStatusError, error_opts
              end
            end
          end
        rescue Faraday::ClientError => e
          raise HttpStatusError, :parent_message => e.message
        end
      end

      private

      # Private: Construct a set of status codes.
      #
      # Accepts an array of Numeric and Enumerable objects which are added or merged to form a set.
      def status_option_array_to_set(status_array)
        set = Set.new
        status_array.each do |item|
          set.add item if item.is_a? Numeric
          set.merge item if item.is_a? Enumerable
        end
        set
      end
    end
    Faraday::Request.register_middleware :raise_on_status => lambda { RaiseOnStatus }
    end
  end
