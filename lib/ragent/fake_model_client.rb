# frozen_string_literal: true

module Ragent
  class FakeModelClient < ModelClient
    def initialize(responses)
      @responses = responses.dup
    end

    def call(_messages)
      raise 'FakeModelClient has no more canned responses' if @responses.empty?

      @responses.shift
    end
  end
end
