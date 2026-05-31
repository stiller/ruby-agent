# frozen_string_literal: true

module Ragent
  TOOL_DEFINITIONS = [
    ToolDefinition.new(
      name: 'list_files',
      description: 'List all files in the repository. Returns relative paths.',
      parameters: { type: 'object', properties: {}, required: [] }
    ),
    ToolDefinition.new(
      name: 'read_file',
      description: 'Read the full contents of a file in the repository.',
      parameters: {
        type: 'object',
        properties: { path: { type: 'string', description: 'Relative path from the repo root.' } },
        required: ['path']
      }
    ),
    ToolDefinition.new(
      name: 'search_text',
      description: 'Search for a string across all files in the repository.',
      parameters: {
        type: 'object',
        properties: { query: { type: 'string', description: 'The text to search for.' } },
        required: ['query']
      }
    )
  ].freeze

  def self.run(prompt, workspace: Workspace::DEFAULT_PATH)
    transcript = Transcript.new
    client = build_client(prompt)

    result = AgentLoop.new(
      prompt: prompt,
      repo_root: workspace,
      model_client: client,
      tool_registry: build_registry(workspace),
      transcript: transcript
    ).run

    transcript.close
    puts result
    puts "Run saved to: #{transcript.run_dir}"
  end

  def self.build_client(prompt)
    if ENV['OPENAI_API_KEY'].to_s.empty?
      FakeModelClient.new([
                            Response::ToolCall.new(tool: 'list_files', args: {}),
                            Response::Final.new(content: "[fake] Received: #{prompt}")
                          ])
    else
      OpenAIClient.new(tool_definitions: TOOL_DEFINITIONS)
    end
  end
  private_class_method :build_client

  def self.build_registry(workspace)
    ToolRegistry.new.tap do |r|
      r.register('list_files') { |_args| Tools::ListFiles.new(workspace).call.join("\n") }
      r.register('read_file') { |args| Tools::ReadFile.new(workspace).call(args[:path] || args['path']).content }
      r.register('search_text') do |args|
        query = args[:query] || args['query']
        Tools::SearchText.new(workspace).call(query).map { |m| "#{m.path}:#{m.line_number}: #{m.line}" }.join("\n")
      end
    end
  end
  private_class_method :build_registry
end
