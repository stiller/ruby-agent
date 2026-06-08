# frozen_string_literal: true

module Ragent
  class Repl
    PROMPT      = '>> '
    PASTE_START = "\e[200~"
    PASTE_END   = "\e[201~"

    def initialize(workspace:, auto_approve:, allow_commands:, config:,
                   input: $stdin, output: $stderr, model_client: nil,
                   artifact_dir: nil, allow_external_artifacts: false)
      @workspace = workspace
      @auto_approve = auto_approve
      @allow_commands = allow_commands
      @config = config
      @input = input
      @output = output
      @model_client = model_client
      @history = nil
      @transcript = Ragent.send(:build_transcript, workspace, artifact_dir: artifact_dir,
                                                              allow_external_artifacts: allow_external_artifacts)
    end

    def run
      Workspace.ensure_ragent_ignored!(@workspace)
      @output.puts 'ragent interactive — type a task, /help for commands, /exit to quit.'
      loop do
        prompt = read_prompt
        break if prompt.nil?
        next if prompt.empty?
        break if handle(prompt) == :exit
      end
      @output.puts "\nBye."
    ensure
      @transcript&.close
    end

    private

    def tty?
      @input.is_a?(IO) && @input.isatty
    end

    def enable_bracketed_paste
      return unless tty?

      @output.print "\e[?2004h"
      @output.flush
    end

    def disable_bracketed_paste
      return unless tty?

      @output.print "\e[?2004l"
      @output.flush
    end

    def read_prompt
      enable_bracketed_paste
      @output.print PROMPT
      @output.flush
      line = @input.gets
      disable_bracketed_paste
      return nil if line.nil?

      return read_bracketed_paste(line.delete_prefix(PASTE_START)) if line.start_with?(PASTE_START)

      buffer = line.chomp
      while paste_pending?
        line = @input.gets
        break if line.nil?

        buffer << "\n" << line.chomp
      end
      buffer.strip
    end

    def read_bracketed_paste(first_chunk)
      buffer = first_chunk.gsub("\r\n", "\n").gsub("\r", "\n").chomp.dup
      loop do
        line = @input.gets
        break if line.nil?

        if (idx = line.index(PASTE_END))
          buffer << "\n" << line[0, idx].gsub("\r", '')
          break
        end
        buffer << "\n" << line.chomp
      end
      buffer.strip
    end

    def paste_pending?
      return false unless @input.is_a?(IO)

      @input.wait_readable(0.15)
    rescue IOError
      false
    end

    def handle(line)
      return dispatch_command(line) if line.start_with?('/')

      run_task(line)
      nil
    end

    def dispatch_command(line)
      case line.split.first
      when '/exit', '/quit' then :exit
      when '/tools'         then cmd_tools
      when '/status'        then cmd_status
      when '/help'          then cmd_help
      else @output.puts "Unknown command '#{line.split.first}'. Type /help for a list."
      end
    end

    def cmd_tools
      Ragent::TOOL_DEFINITIONS.each { |t| @output.puts "  #{t.name}" }
    end

    def cmd_status
      @output.puts "Repo root:      #{@workspace}"
      @output.puts "Approval mode:  #{@config.approval_mode}"
      @output.puts "Allow commands: #{@allow_commands}"
      @output.puts "History turns:  #{history_turns}"
    end

    def cmd_help
      @output.puts '  /tools   — list available tools'
      @output.puts '  /status  — show repo and session info'
      @output.puts '  /exit    — quit (also /quit or Ctrl-D)'
    end

    def history_turns
      return 0 unless @history

      @history.count { |m| m[:role] == 'user' }
    end

    def run_task(prompt)
      loop_obj = Ragent.send(
        :build_loop,
        prompt, @workspace, @transcript,
        build_approver, build_command_approver,
        allow_commands: @allow_commands, config: @config,
        history: @history, model_client: @model_client
      )
      loop_obj.on_tool_call = ->(tool, args) { Ragent.send(:print_tool_progress, tool, args) }
      result = loop_obj.run
      @history = loop_obj.messages + [{ role: 'assistant', content: result }]
      @output.puts "\n#{Terminal.answer_header}\n#{result}\n"
    rescue StandardError => e
      @output.puts "Error: #{e.message}"
    end

    def build_approver
      PatchApprover.new(auto_approve: @auto_approve || @config.approval_mode == 'auto')
    end

    def build_command_approver
      CommandApprover.new(
        auto_approve: @auto_approve || @config.approval_mode == 'auto',
        allow_commands: @allow_commands,
        allowed_commands: @config.allowed_commands
      )
    end
  end
end
