# frozen_string_literal: true

module Ragent
  class ModelClient
    # messages: Array of { role: String, content: String }
    # Returns: Response::Final or Response::ToolCall
    def call(_messages)
      raise NotImplementedError, "#{self.class} must implement #call"
    end
  end
end
