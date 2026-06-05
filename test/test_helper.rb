# frozen_string_literal: true

unless defined?(RAGENT_TEST_HELPER_LOADED)
  RAGENT_TEST_HELPER_LOADED = true

  require 'net/http'
  require_relative '../lib/ragent'

  module Ragent
    module TestNetworkGuard
      def request(req, _body = nil)
        target = req.uri || "#{use_ssl? ? 'https' : 'http'}://#{address}:#{port}#{req.path}"
        raise "Outgoing HTTP request blocked in tests: #{req.method} #{target}"
      end
    end

    module TestBuildClient
      def build_client(prompt)
        FakeModelClient.new([
                              Response::ToolCall.new(tool: 'list_files', args: {}),
                              Response::Final.new(content: "[fake] Received: #{prompt}")
                            ])
      end
    end

    singleton_class.prepend(TestBuildClient)
  end

  Net::HTTP.prepend(Ragent::TestNetworkGuard)
end

require 'minitest/autorun'
