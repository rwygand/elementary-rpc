require 'spec_helper'
require 'support/clients/base_elementary_client'
require 'support/clients/elementary_client_using_anti_pattern'

def sendAndVerify(msg)
  response = client.invoke_echo_service(Elementary::Rspec::String.new(:data => msg))
  expect(response).to be_rejected
  expect(response.reason.class).to be Elementary::Middleware::HttpStatusError
  expect(response.reason.connection_refused?).to be true
  expect(response.reason.message).to include("connection refused: localhost:8090")
end

# This test requires that no process be listening at localhost:8090
describe ElementaryClientUsingAntiPattern, "http connection returning error code 503", :type => :integration do
  subject (:client) {ElementaryClientUsingAntiPattern.new()}
  describe "#initialize" do
    it "creates a connection" do
      expect(client.connection).not_to be_nil
    end
  end
  describe "#invoke_service" do
    context 'with http connection returning error connection refused' do
      it "invokes echo service" do
        sendAndVerify('rspec1')
      end
    end
  end
end