# frozen_string_literal: true

module Ragent
  module Response
    Final = Struct.new(:content, keyword_init: true) do
      def type = 'final'
    end

    ToolCall = Struct.new(:tool, :args, :id, keyword_init: true) do
      def type = 'tool_call'
    end
  end
end
