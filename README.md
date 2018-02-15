# Elementary RPC

[![Build Status](https://travis-ci.org/lookout/elementary-rpc.svg?branch=master)](https://travis-ci.org/lookout/elementary-rpc) [![Gem Version](https://badge.fury.io/rb/elementary-rpc.svg)](http://badge.fury.io/rb/elementary-rpc)

Elementary RPC is a basic
[Protobuf](https://developers.google.com/protocol-buffers/docs/overview) HTTP
RPC gem which aims to provide:

 * Easy RPC usage
 * Parallelism by default
 * An easily extended RPC request pipeline

### Sample Usage

For the following Protobuf RPC service definition:

```
package echoserv;

message String {
  required string data  = 1;
  optional int64 status = 2;
}

service Simple {
  rpc Echo (String) returns (String);
  rpc Reverse (String) returns (String);
}
```

A corresponding Ruby client might look something like this:

```ruby
require 'rubygems'
require 'elementary'

require 'echoserv/service.pb' # Include our protobuf object declarations


# You may, optionally, include a :protocol (e.g. 'https') key in a host hash
hosts = [{:host => 'localhost', :port => '9292', :prefix => '/rpcserv'}]


# Let's use the Statsd middleware to send RPC timing and count information to
# Graphite (this presumes we have already used `Lookout::Statsd.create_instance`
# elsewhere in our code)
Elementary.use(Elementary::Middleware::Statsd, :client => Lookout::Statsd.instance)


# Create our Connection object that knows about our Protobuf service
# definition
def connection
  return @connection if @connection

  @connection = Elementary::Connection.new(Echoserv::Simple,
                                             :hosts => hosts)
end
# We can also use existing Faraday middleware, since our HTTP transport is built
# on Faraday:
c = Elementary::Connection.new(Echoserv::Simple,
                                :hosts => hosts,
                                :transport_options => {
                                  :faraday_middleware => [
                                    [ FaradayMiddleware::FollowRedirects, :limit => 2 ]
                                   ]
                                 })



# Create a Protobuf message to send over RPC
msg = Echoserv::String.new(:data => str)


echoed = c.rpc.echo(msg) # => Elementary::Future
reversed = c.rpc.reverse(msg) # => Elementary::Future

sleep 10 # Twiddle our thumbs doing other things

puts {
  :echoed => echoed.value, # resolve the future and get our value out
  :reversed => reversed.value,
}.to_json
```

## Installation

Add this line to your application's Gemfile:

    gem 'elementary-rpc'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elementary-rpc

## Contributing

1. Fork it ( https://github.com/[my-github-username]/elementary-rpc/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

### Testing

Install ha-proxy for your OS

Sample ha-proxy config can be found in `spec/support/haproxy.conf`.
```
Start ha-proxy listener

    haproxy -f spec/support/haproxy.conf

Start the server hosting the rpc as below:

    bundle exec rpc_server start ./spec/support/simpleservice.rb -p 8000 --http

Run the tests

    bundle exec rspec spec
