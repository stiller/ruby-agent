# frozen_string_literal: true

module Ragent
  def self.run(prompt, workspace: Workspace::DEFAULT_PATH)
    transcript = Transcript.new
    client = FakeModelClient.new([
                                   Response::ToolCall.new(tool: 'list_files', args: {}),
                                   Response::Final.new(content: "[fake] Received: #{prompt}")
                                 ])

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
