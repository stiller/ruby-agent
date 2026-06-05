# frozen_string_literal: true

module Ragent
  class CommandApprover
    def initialize(auto_approve: false, allow_commands: false, input: $stdin, output: $stderr)
      @auto_approve = auto_approve
      @allow_commands = allow_commands
      @input = input
      @output = output
    end

    def call(proposal)
      @output.puts "$ #{proposal.command}"
      @output.puts "Reason: #{proposal.reason}"
      return true if @auto_approve && @allow_commands

      @output.print 'Run this command? [y/N] '
      @input.gets&.strip&.downcase == 'y'
    end
  end
end
