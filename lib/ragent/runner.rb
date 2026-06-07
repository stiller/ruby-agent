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
      description: 'List files and directories in the repository. ' \
                   'Use path to start from a subdirectory. ' \
                   'Use max_depth: 1 to see only direct children (files and directories). ' \
                   'Without max_depth, lists all files recursively (up to 200).',
      parameters: {
        type: 'object',
        properties: {
          path: {
            type: 'string',
            description: 'Subdirectory to list, relative to repo root. Omit to list from root.'
          },
          max_depth: {
            type: 'integer',
            description: 'Max depth to traverse. 1 = direct children only. Omit for full recursive listing.'
          }
        },
        required: []
      }
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
    ),
    ToolDefinition.new(
      name: 'replace_in_file',
      description: 'Replace an exact string that appears exactly once in a file. ' \
                   'Fails if old_text is not found or appears more than once. ' \
                   'Use replace_all_in_file when old_text appears multiple times.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Relative path from the repo root.' },
          old_text: { type: 'string', description: 'The exact text to find and replace. Must appear exactly once.' },
          new_text: { type: 'string', description: 'The replacement text.' }
        },
        required: %w[path old_text new_text]
      }
    ),
    ToolDefinition.new(
      name: 'replace_all_in_file',
      description: 'Replace every occurrence of a string in a file. ' \
                   'Fails only if old_text is not found at all. ' \
                   'Use this when old_text appears multiple times and all instances should be changed.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Relative path from the repo root.' },
          old_text: { type: 'string', description: 'The exact text to find and replace everywhere.' },
          new_text: { type: 'string', description: 'The replacement text.' }
        },
        required: %w[path old_text new_text]
      }
    )
  ].freeze

  def self.run(prompt, workspace: Workspace::DEFAULT_PATH, auto_approve: false, keep_runs: true, allow_commands: false)
    Workspace.ensure_ragent_ignored!(workspace)
    transcript = Transcript.new(runs_dir: Workspace.resolve_runs_dir(workspace))
    Terminal.debug("run_dir=#{transcript.run_dir}")
    config = Config.new(workspace)
    approver = PatchApprover.new(auto_approve: auto_approve || config.approval_mode == 'auto')
    command_approver = CommandApprover.new(
      auto_approve: auto_approve || config.approval_mode == 'auto',
      allow_commands: allow_commands,
      allowed_commands: config.allowed_commands
    )
    loop = build_loop(prompt, workspace, transcript, approver, command_approver,
                      allow_commands: allow_commands, config: config)
    loop.on_tool_call = method(:print_tool_progress)
    print_result(loop.run)
  ensure
    transcript&.close
    keep_runs ? warn("Run artifacts kept at: #{transcript&.run_dir}") : FileUtils.rm_rf(transcript&.run_dir)
  end

  def self.build_loop(prompt, workspace, transcript, approver, command_approver,
                      config:, allow_commands: false, history: nil, model_client: nil)
    instructions = history ? '' : load_instructions(workspace)
    registry = build_registry(
      workspace, run_dir: transcript.run_dir, approver: approver,
                 command_approver: command_approver, allow_commands: allow_commands, config: config
    )
    AgentLoop.new(
      prompt: prompt,
      repo_root: workspace,
      model_client: model_client || build_client(prompt),
      tool_registry: registry,
      transcript: transcript,
      system_prompt: build_system_prompt(workspace, instructions: instructions),
      history: history
    )
  end
  private_class_method :build_loop

  def self.load_instructions(workspace)
    entries = AgentInstructions.new(workspace).load
    entries.map(&:first).each { |path| warn "Loaded repo instructions from #{path}" }
    entries.map(&:last).join("\n\n")
  end
  private_class_method :load_instructions

  def self.print_tool_progress(tool, args)
    parts = args.map { |k, v| "#{k}: #{format_arg(v)}" }.join(', ')
    warn Terminal.tool_line(tool, parts)
  end
  private_class_method :print_tool_progress

  def self.format_arg(val, max = 80)
    s = val.to_s.gsub(/\s+/, ' ').strip
    s.length > max ? "#{s[0, max]}…" : s
  end
  private_class_method :format_arg

  def self.print_result(content)
    warn "\n#{Terminal.answer_header}"
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

  def self.build_system_prompt(workspace, instructions: nil)
    Prompts::SystemPrompt.new(repo_root: workspace, tools: TOOL_DEFINITIONS.map(&:name), instructions: instructions)
  end
  private_class_method :build_system_prompt

  def self.build_registry(workspace, run_dir:, approver:, command_approver:, config:, allow_commands: false)
    get = ->(args, k) { args[k.to_sym] || args[k.to_s] }
    t = build_tools(workspace, config)
    patch_handler = build_patch_handler(workspace, run_dir, approver)
    replace_handler = build_replace_handler(workspace, run_dir, approver)
    replace_all_handler = build_replace_all_handler(workspace, run_dir, approver)
    command_handler = build_command_handler(workspace, command_approver, allow_commands: allow_commands)
    ToolRegistry.new.tap do |r|
      r.register('list_files') do |args|
        t[:list].call(
          path: get.call(args, 'path'),
          max_depth: get.call(args, 'max_depth')&.to_i
        ).join("\n")
      end
      r.register('read_file') { |args| t[:read].call(get.call(args, 'path')).content }
      r.register('search_text') do |args|
        t[:search].call(get.call(args, 'query')).map { |m| "#{m.path}:#{m.line_number}: #{m.line}" }.join("\n")
      end
      r.register('propose_patch') { |args| patch_handler.call(get.call(args, 'diff')) }
      r.register('replace_in_file') do |args|
        replace_handler.call(get.call(args, 'path'), get.call(args, 'old_text'), get.call(args, 'new_text'))
      end
      r.register('replace_all_in_file') do |args|
        replace_all_handler.call(get.call(args, 'path'), get.call(args, 'old_text'), get.call(args, 'new_text'))
      end
      r.register('propose_command') do |args|
        command_handler.call(get.call(args, 'command'), get.call(args, 'reason'))
      end
    end
  end
  private_class_method :build_registry

  def self.build_tools(workspace, config)
    {
      list: Tools::ListFiles.new(workspace, ignored_paths: config.ignored_paths),
      read: Tools::ReadFile.new(workspace, max_size: config.max_file_size || Tools::ReadFile::MAX_SIZE),
      search: Tools::SearchText.new(workspace, ignored_paths: config.ignored_paths,
                                               limit: config.max_search_results || Tools::SearchText::DEFAULT_LIMIT)
    }
  end
  private_class_method :build_tools

  def self.build_command_handler(workspace, command_approver, allow_commands: false)
    lambda do |command, reason|
      unless allow_commands
        warn 'Note: shell commands are not enabled. Re-run with --allow-commands to enable them.'
        return 'Shell commands are not enabled.'
      end

      proposal = Tools::ProposeCommand.new.call(command, reason)
      return proposal.to_s unless proposal.is_a?(Tools::ProposeCommand::Result)

      if command_approver.call(proposal)
        Tools::RunCommand.new(workspace, output: $stderr).call(command).to_s
      else
        'Command denied by user.'
      end
    end
  end
  private_class_method :build_command_handler

  def self.apply_approved_patch(workspace, run_dir, approver, patch_file)
    applier = Tools::ApplyPatch.new(workspace)
    preflight = applier.check(patch_file)
    return preflight.to_s if preflight

    checkpoint = Checkpoint.new(workspace, run_dir: run_dir)
    warn 'Warning: workspace is not a git repository. Changes cannot be checkpointed.' unless checkpoint.git_repo?

    if approver.call(patch_file)
      checkpoint.save(patch_file)
      applier.call(patch_file).to_s
    else
      "Patch denied by user. Saved at: #{patch_file}"
    end
  end
  private_class_method :apply_approved_patch

  def self.build_patch_handler(workspace, run_dir, approver)
    lambda do |diff|
      proposal = Tools::ProposePatch.new(workspace, run_dir: run_dir).call(diff)
      return proposal.to_s unless proposal.is_a?(Tools::ProposePatch::Result)

      apply_approved_patch(workspace, run_dir, approver, proposal.patch_file)
    end
  end
  private_class_method :build_patch_handler

  def self.build_replace_handler(workspace, run_dir, approver)
    lambda do |path, old_text, new_text|
      result = Tools::ReplaceInFile.new(workspace, run_dir: run_dir).call(path, old_text, new_text)
      return result.to_s unless result.is_a?(Tools::ReplaceInFile::Result)

      apply_approved_patch(workspace, run_dir, approver, result.patch_file)
    end
  end
  private_class_method :build_replace_handler

  def self.build_replace_all_handler(workspace, run_dir, approver)
    lambda do |path, old_text, new_text|
      result = Tools::ReplaceAllInFile.new(workspace, run_dir: run_dir).call(path, old_text, new_text)
      return result.to_s unless result.is_a?(Tools::ReplaceAllInFile::Result)

      apply_approved_patch(workspace, run_dir, approver, result.patch_file)
    end
  end
  private_class_method :build_replace_all_handler
end
