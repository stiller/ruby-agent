# The Ragent module provides a framework for automating tool usage within a project workspace.
# It defines various tool operations such as listing files, reading file contents, searching text,
# and proposing code changes. The module manages the execution of these tools in response to input
# prompts, supporting interactions with both actual and mock API clients. It ensures operations can be
# auto-approved and tracks the execution process via transcripts.
#
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
      description: 'Propose a code change as a plain unified diff ' \
                   '(--- / +++ / @@ format only, no git headers). Not applied.',
      parameters: {
        type: 'object',
        properties: { diff: { type: 'string', description: 'A unified diff in standard unified format.' } },
        required: ['diff']
      }
    ),
    ToolDefinition.new(
      name: 'propose_command',
      description: 'Propose a shell command to run. Requires user approval before execution.',
      parameters: {
        type: 'object',
        properties: {
          command: { type: 'string', description: 'The shell command to execute.' },
          reason: { type: 'string', description: 'Why this command is needed.' }
        },
        required: %w[command reason]
      }
    )
  ].freeze

  def self.run(prompt, workspace: Workspace::DEFAULT_PATH, auto_approve: false, keep_runs: true, allow_commands: false)
    Workspace.ensure_ragent_ignored!(workspace)
    transcript = Transcript.new(runs_dir: File.join(workspace, '.ragent', 'runs'))
    approver = PatchApprover.new(auto_approve: auto_approve)
    command_approver = CommandApprover.new(auto_approve: auto_approve, allow_commands: allow_commands)
    loop = build_loop(prompt, workspace, transcript, approver, command_approver, allow_commands: allow_commands)
    loop.on_tool_call = method(:print_tool_progress)
    result = loop.run
    print_result(result)
  ensure
    transcript&.close
    keep_runs ? warn("Run artifacts kept at: #{transcript&.run_dir}") : FileUtils.rm_rf(transcript&.run_dir)
  end

  def self.build_loop(prompt, workspace, transcript, approver, command_approver, allow_commands: false)
    registry = build_registry(
      workspace, run_dir: transcript.run_dir, approver: approver,
                 command_approver: command_approver, allow_commands: allow_commands
    )
    AgentLoop.new(
      prompt: prompt,
      repo_root: workspace,
      model_client: build_client(prompt),
      tool_registry: registry,
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

  def self.print_result(content)
    warn "\n=== Answer ==="
    puts content
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

  def self.build_registry(workspace, run_dir:, approver:, command_approver:, allow_commands: false)
    get = ->(args, k) { args[k.to_sym] || args[k.to_s] }
    patch_handler = build_patch_handler(workspace, run_dir, approver)
    command_handler = build_command_handler(workspace, command_approver, allow_commands: allow_commands)
    ToolRegistry.new.tap do |r|
      r.register('list_files') { |_args| Tools::ListFiles.new(workspace).call.join("\n") }
      r.register('read_file') { |args| Tools::ReadFile.new(workspace).call(get.call(args, 'path')).content }
      r.register('search_text') do |args|
        Tools::SearchText.new(workspace).call(get.call(args, 'query'))
                         .map { |m| "#{m.path}:#{m.line_number}: #{m.line}" }.join("\n")
      end
      r.register('propose_patch') { |args| patch_handler.call(get.call(args, 'diff')) }
      r.register('propose_command') do |args|
        command_handler.call(get.call(args, 'command'), get.call(args, 'reason'))
      end
    end
  end
  private_class_method :build_registry

  def self.build_command_handler(workspace, command_approver, allow_commands: false)
    lambda do |command, reason|
      unless allow_commands
        warn 'Note: shell commands are not enabled. Re-run with --allow-commands to enable them.'
        return 'Shell commands are not enabled.'
      end

      proposal = Tools::ProposeCommand.new.call(command, reason)
      return proposal.to_s unless proposal.is_a?(Tools::ProposeCommand::Result)

      if command_approver.call(proposal)
        Tools::RunCommand.new(workspace).call(command).to_s
      else
        'Command denied by user.'
      end
    end
  end
  private_class_method :build_command_handler

  def self.build_patch_handler(workspace, run_dir, approver)
    lambda do |diff|
      proposal = Tools::ProposePatch.new(workspace, run_dir: run_dir).call(diff)
      return proposal.to_s unless proposal.is_a?(Tools::ProposePatch::Result)

      applier = Tools::ApplyPatch.new(workspace)
      preflight = applier.check(proposal.patch_file)
      return preflight.to_s if preflight

      checkpoint = Checkpoint.new(workspace, run_dir: run_dir)
      warn 'Warning: workspace is not a git repository. Changes cannot be checkpointed.' unless checkpoint.git_repo?

      if approver.call(proposal.patch_file)
        checkpoint.save(proposal.patch_file)
        applier.call(proposal.patch_file).to_s
      else
        "Patch denied by user. Saved at: #{proposal.patch_file}"
      end
    end
  end
  private_class_method :build_patch_handler
end
