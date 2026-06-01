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
    ),
    ToolDefinition.new(
      name: 'propose_patch',
      description: 'Propose a code change as a unified diff. Saved for review but NOT applied.',
      parameters: {
        type: 'object',
        properties: { diff: { type: 'string', description: 'A unified diff in standard unified format.' } },
        required: ['diff']
      }
    )
  ].freeze

  def self.run(prompt, workspace: Workspace::DEFAULT_PATH)
    transcript = Transcript.new
    loop = build_loop(prompt, workspace, transcript)
    loop.on_tool_call = method(:print_tool_progress)
    result = loop.run
    transcript.close
    print_result(result, transcript.run_dir)
  end

  def self.build_loop(prompt, workspace, transcript)
    AgentLoop.new(
      prompt: prompt,
      repo_root: workspace,
      model_client: build_client(prompt),
      tool_registry: build_registry(workspace, run_dir: transcript.run_dir),
      transcript: transcript,
      system_prompt: build_system_prompt(workspace)
    )
  end
  private_class_method :build_loop

  def self.print_tool_progress(tool, args)
    parts = args.map { |k, v| "#{k}: #{format_arg(v)}" }.join(', ')
    warn parts.empty? ? "[#{tool}]" : "[#{tool}] #{parts}"
  end
  private_class_method :print_tool_progress

  def self.format_arg(val, max = 80)
    s = val.to_s.gsub(/\s+/, ' ').strip
    s.length > max ? "#{s[0, max]}…" : s
  end
  private_class_method :format_arg

  def self.print_result(content, run_dir)
    warn "\n=== Answer ==="
    puts content
    warn "\nRun saved to: #{run_dir}"
  end
  private_class_method :print_result

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

  def self.build_system_prompt(workspace)
    Prompts::SystemPrompt.new(repo_root: workspace, tools: TOOL_DEFINITIONS.map(&:name))
  end
  private_class_method :build_system_prompt

  def self.build_registry(workspace, run_dir:)
    get = ->(args, k) { args[k.to_sym] || args[k.to_s] }
    ToolRegistry.new.tap do |r|
      r.register('list_files') { |_args| Tools::ListFiles.new(workspace).call.join("\n") }
      r.register('read_file') { |args| Tools::ReadFile.new(workspace).call(get.call(args, 'path')).content }
      r.register('search_text') do |args|
        Tools::SearchText.new(workspace).call(get.call(args, 'query'))
                         .map { |m| "#{m.path}:#{m.line_number}: #{m.line}" }.join("\n")
      end
      r.register('propose_patch') do |args|
        Tools::ProposePatch.new(workspace, run_dir: run_dir).call(get.call(args, 'diff')).to_s
      end
    end
  end
  private_class_method :build_registry
end
