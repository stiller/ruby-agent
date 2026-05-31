# frozen_string_literal: true

module Ragent
  class AgentLoop
    MAX_ITERATIONS = 10

    def initialize(prompt:, repo_root:, model_client:, tool_registry:, max_iterations: MAX_ITERATIONS)
      @prompt = prompt
      @repo_root = repo_root
      @model_client = model_client
      @tool_registry = tool_registry
      @max_iterations = max_iterations
    end

    def run
      messages = [{ role: 'user', content: @prompt }]

      @max_iterations.times do
        response = @model_client.call(messages)

        case response.type
        when 'final'
          return response.content
        when 'tool_call'
          result = @tool_registry.call(response.tool, response.args)
          messages << { role: 'tool_result', tool: response.tool, content: result.to_s }
        else
          raise "Unexpected response type: '#{response.type}'"
        end
      end

      raise "Agent exceeded maximum of #{@max_iterations} iterations"
    end
  end
end
