# frozen_string_literal: true

module Ragent
  class AgentLoop
    MAX_ITERATIONS = 10

    def initialize(prompt:, repo_root:, model_client:, tool_registry:,
                   max_iterations: MAX_ITERATIONS, transcript: nil)
      @prompt = prompt
      @repo_root = repo_root
      @model_client = model_client
      @tool_registry = tool_registry
      @max_iterations = max_iterations
      @transcript = transcript
    end

    def run
      @transcript&.log_prompt(@prompt)
      messages = [{ role: 'user', content: @prompt }]

      @max_iterations.times do
        response = @model_client.call(messages)
        @transcript&.log_model_response(response)
        return response.content if response.type == 'final'

        dispatch_tool_call(response, messages)
      end

      raise "Agent exceeded maximum of #{@max_iterations} iterations"
    end

    private

    def dispatch_tool_call(response, messages)
      raise "Unexpected response type: '#{response.type}'" unless response.type == 'tool_call'

      result = @tool_registry.call(response.tool, response.args)
      @transcript&.log_tool_result(response.tool, result)
      messages << { role: 'tool_result', tool: response.tool, content: result.to_s }
    end
  end
end
