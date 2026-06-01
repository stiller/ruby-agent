# frozen_string_literal: true

module Ragent
  class PatchApprover
    def initialize(auto_approve: false, input: $stdin, output: $stderr)
      @auto_approve = auto_approve
      @input = input
      @output = output
    end

    def call(patch_file)
      @output.puts File.read(patch_file)
      return true if @auto_approve

      @output.print 'Apply this patch? [y/N] '
      @input.gets&.strip&.downcase == 'y'
    end
  end
end
