# frozen_string_literal: true

module Ragent
  ToolDefinition = Struct.new(:name, :description, :parameters, keyword_init: true) do
    def to_openai_schema
      {
        type: 'function',
        function: {
          name: name,
          description: description,
          parameters: parameters || { type: 'object', properties: {}, required: [] }
        }
      }
    end
  end
end
