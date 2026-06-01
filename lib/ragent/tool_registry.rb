# frozen_string_literal: true

module Ragent
  class ToolRegistry
    class UnknownToolError < StandardError
    end

    def initialize
      @tools = {}
    end

    def register(name, &block)
      @tools[name.to_s] = block
      self
    end

    def call(name, args)
      tool = @tools[name.to_s] or raise UnknownToolError, "unknown tool: '#{name}'"
      tool.call(args)
    end
  end
end
