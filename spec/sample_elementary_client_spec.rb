require 'spec_helper'
require 'support/clients/base_elementary_client'
require 'support/clients/sample_elementary_client'

def send_and_verify_http_error_503(msg)
  response = client.invoke_error_service(Elementary::Rspec::String.new(:data => msg))
  expect(response).to be_rejected
  expect(response.reason.class).to be Elementary::Middleware::HttpStatusError
  expect(response.reason.message).to include("returned an HTTP response status of 503, so an exception was raised.")
  expect(response.reason.status_code).to eql 503
  expect(response.reason.message).to include("Elementary::Rspec::Simple#error")
end

def send_and_verify_http_error_500(msg)
  response = client.invoke_error_service(Elementary::Rspec::String.new(:data => msg))
  expect(response).to be_rejected
  expect(response.reason.class).to be Elementary::Errors::RPCFailure
  expect(response.reason.status_code).to eql 500
  expect(response.reason.message).to include("sample failure")
  expect(response.reason.message).to include("Elementary::Rspec::Simple#error")
end

def send_and_verify_http_error_400(msg)
  response = client.invoke_bad_request_data_service(Elementary::Rspec::String.new(:data => msg))
  expect(response).to be_rejected
  expect(response.reason.class).to be Elementary::Errors::RPCFailure
  expect(response.reason.status_code).to eql 400
  expect(response.reason.message).to include("sample bad request data failure")
  expect(response.reason.message).to include("Elementary::Rspec::Simple#bad_request_data_method")
end

def send_and_verify_http_error_404(msg)
  response = client.invoke_service_not_found_service(Elementary::Rspec::String.new(:data => msg))
  expect(response).to be_rejected
  expect(response.reason.class).to be Elementary::Errors::RPCFailure
  expect(response.reason.status_code).to eql 404
  expect(response.reason.message).to include("sample service not found failure")
  expect(response.reason.message).to include("Elementary::Rspec::Simple#service_not_found_method")
end

def send_and_verify_connection_refused(msg)
  response = client.invoke_error_service(Elementary::Rspec::String.new(:data => msg))
  expect(response).to be_rejected
  expect(response.reason.class).to be Elementary::Middleware::HttpStatusError
  expect(response.reason.status_code).to be nil
  expect(response.reason.connection_refused?).to be true
  expect(response.reason.message).to include("connection refused: localhost:8090")
  expect(response.reason.message).to include("Elementary::Rspec::Simple#error")
end

# This test requires ha-proxy to be listening at localhost:8080, but no real rpc to be available
describe SampleElementaryClient, "http connection returning error code 503", :type => :integration do
  subject (:client) {SampleElementaryClient.new(8070)}
  describe "#initialize" do
    it "creates a connection" do
      expect(client.connection).not_to be_nil
    end
  end
  describe "#invoke_error_service" do
    context 'with http connection returning error code 503' do
      it "invokes error service" do
        send_and_verify_http_error_503('rspec1')
      end
    end
  end
end

# This test requires that no process be listening at localhost:8090
describe SampleElementaryClient, "http connection returning connection refused error", :type => :integration do
  subject (:client) {SampleElementaryClient.new(8090)}
  describe "#initialize" do
    it "creates a connection" do
      expect(client.connection).not_to be_nil
    end
  end
  describe "#invoke_error_service" do
    context 'with http connection failed' do
      it "invokes error service" do
        send_and_verify_connection_refused('rspec1')
      end
    end
  end
end

# These tests requires ha-proxy to be listening at localhost:8080 routing requests to online rpc server
describe SampleElementaryClient, "rpc requests returning non-connection related errors", :type => :integration do
  subject (:client) {SampleElementaryClient.new(8080)}
  describe "#initialize" do
    it "creates a connection" do
      expect(client.connection).not_to be_nil
    end
  end
  describe "#invoke_bad_request_data_service", "handles http error 400" do
    it "invokes bad request data service" do
      send_and_verify_http_error_400('rspec1')
    end
  end
  describe "#invoke_service_not_found_service", "handles http error 404" do
    it "invokes service not found service" do
      send_and_verify_http_error_404('rspec1')
    end
  end
  describe "#invoke_service_returning_failure", "handles http error 500" do
    it "invokes service returning failure" do
      send_and_verify_http_error_500('rspec1')
    end
  end
end
