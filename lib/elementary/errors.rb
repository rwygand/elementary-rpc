module Elementary
  module Errors
    # A simple root class to signify an failure on the RPC server side (see
    #   "rpc_failed 'message'")
    class RPCFailure < StandardError
      attr_reader :status_code, :method, :url, :header_message, :header_code

      def initialize(opts = {})
        @status_code = opts.fetch(:status_code, nil)
        @method = opts.fetch(:method, "<Unknown Method>")
        @url = opts.fetch(:url, "<Unknown URL>")
        @header_code = opts.fetch(:header_code, "<Unknown Header Code>")
        @header_message = opts.fetch(:header_message, "<Unknown Header Message>")
        super "Error #{@header_code}: #{@header_message}"
      end
    end
  end
end
