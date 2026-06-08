# frozen_string_literal: true

require 'json'

module Ragent
  class AgentLoop
    MAX_ITERATIONS = 20

    attr_writer :on_tool_call
    attr_reader :messages

    def initialize(prompt:, repo_root:, model_client:, tool_registry:,
                   max_iterations: MAX_ITERATIONS, transcript: nil, system_prompt: nil,
                   history: nil)
      @prompt = prompt
      @repo_root = repo_root
      @model_client = model_client
      @tool_registry = tool_registry
      @max_iterations = max_iterations
      @transcript = transcript
      @system_prompt = system_prompt
      @history = history
      @messages = []
    end

    def run
      @transcript&.log_prompt(@prompt)
      @messages = if @history
                    @history + [{ role: 'user', content: @prompt }]
                  else
                    fresh_messages
                  end

      @max_iterations.times do
        response = @model_client.call(@messages)
        @transcript&.log_model_response(response)
        return response.content if response.type == 'final'

        dispatch_tool_call(response, @messages)
      end

      raise "Agent exceeded maximum of #{@max_iterations} iterations"
    end

    private

    def fresh_messages
      msgs = []
      msgs << { role: 'system', content: @system_prompt.to_s } if @system_prompt
      msgs << { role: 'user', content: @prompt }
      msgs
    end

    def dispatch_tool_call(response, messages)
      raise "Unexpected response type: '#{response.type}'" unless response.type == 'tool_call'

      Terminal.debug("tool_call #{JSON.generate({ tool: response.tool, args: response.args })}")
      @on_tool_call&.call(response.tool, response.args)
      messages << { role: 'assistant', tool_calls: [{ id: response.id, name: response.tool, args: response.args }] }

      result = @tool_registry.call(response.tool, response.args)
      @transcript&.log_tool_result(response.tool, result)
      messages << { role: 'tool', tool_call_id: response.id, content: result.to_s }
    end
  end
end
