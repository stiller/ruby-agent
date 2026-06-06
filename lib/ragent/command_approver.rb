# frozen_string_literal: true

module Ragent
  class CommandApprover
    def initialize(auto_approve: false, allow_commands: false, allowed_commands: [], input: $stdin, output: $stderr)
      @auto_approve = auto_approve
      @allow_commands = allow_commands
      @allowed_commands = allowed_commands
      @input = input
      @output = output
    end

    def call(proposal)
      @output.puts "\n#{Terminal.section('Proposed command')}"
      @output.puts Terminal.fmt("$ #{proposal.command}", :bold)
      @output.puts "Reason: #{proposal.reason}"
      return true if @auto_approve && @allow_commands
      return true if allowlisted?(proposal.command)

      @output.print 'Run this command? [y/N] '
      @input.gets&.strip&.downcase == 'y'
    end

    private

    def allowlisted?(command)
      @allowed_commands.any? { |prefix| command == prefix || command.start_with?("#{prefix} ") }
    end
  end
end
