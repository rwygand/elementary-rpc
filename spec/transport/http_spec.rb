require 'spec_helper'
require 'elementary/transport/http'

class FakeMiddleware1 ; end
class FakeMiddleware2 ; end

describe Elementary::Transport::HTTP do
  let(:hosts) { [] }
  let(:opts) { {} }
  let(:http) { described_class.new(hosts, opts) }

  describe '#host_url' do
    subject(:host_url) { http.send(:host_url) }

    context 'without a prefix' do
      let(:hosts) do
        [
          {
            :host => 'localhost',
            :port => 8080,
          }
        ]
      end

      it { should eql 'http://localhost:8080/' }
    end

    context 'with a prefix' do
      let(:hosts) do
        [
          {
            :host => 'localhost',
            :port => 8080,
            :prefix => 'rspec'
          }
        ]
      end

      it { should eql 'http://localhost:8080/rspec' }
    end

    context 'without a protocol' do
      let(:hosts) do
        [ { :host => 'localhost', :port => 8080 } ]
      end

      it { should eql 'http://localhost:8080/' }
    end

    context 'with a protocol' do
      let(:hosts) do
        [ { :host => 'localhost', :port => 8080, :protocol => 'https' } ]
      end

      it { should eql 'https://localhost:8080/' }
    end
  end

  describe '#client' do
    let(:hosts) do
      [
        {
          :host => 'localhost',
          :port => 8080,
        }
      ]
    end
    subject(:client) { http.send(:client) }

    it { should be_instance_of Faraday::Connection }

    it 'should cache connections' do
      first = http.send(:client)
      second = http.send(:client)

      # Object identity!
      expect(first).to be second
    end

    context 'with options passed to the initializer' do
      let(:opts) do
        {
          :request => {:timeout => 3, :open_timeout => 1},
        }
      end

      it 'should pass options to Faraday.new' do
        expect(Faraday).to receive(:new).with(hash_including(opts)).and_call_original
        expect(client).to be_instance_of Faraday::Connection
      end
    end

    context 'with faraday middleware passed to the initializer' do
      let(:opts) do
        {
          :faraday_middleware => [
            [ FakeMiddleware1, { :middleware_level => 1} ],
            [ FakeMiddleware2, { :middleware_level => 2} ]
          ]
        }
      end

      it 'should use those middlewares' do
        expect(client.builder.handlers).to include(FakeMiddleware1)
        expect(client.builder.handlers).to include(FakeMiddleware2)
        middleware_opts = client.builder.handlers.map do |h|
          h.instance_variable_get(:@args)
        end
        expect(middleware_opts).to include([{ :middleware_level => 1 }])
        expect(middleware_opts).to include([{ :middleware_level => 2 }])

        expect(client).to be_instance_of Faraday::Connection
      end
    end
  end
end
