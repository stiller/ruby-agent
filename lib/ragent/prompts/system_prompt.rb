# frozen_string_literal: true

module Ragent
  module Prompts
    class SystemPrompt
      def initialize(repo_root:, tools:, instructions: nil)
        @repo_root = repo_root
        @tools = tools
        @instructions = instructions
      end

      def to_s
        base = <<~PROMPT
          You are a coding assistant. The target repository is at #{@repo_root}. This is the only directory you can access.

          Rules:
          - Never guess or assume file contents. Always read files with the appropriate tool.
          - Use tools to explore the repository before drawing conclusions.
          - Work in small, verifiable steps. Inspect before summarizing.
          - Only use the tools provided by this harness: #{@tools.join(', ')}.
          - When finished, provide a concise summary of what you did and what you found.
          - Use propose_command to run shell commands. Each command requires user approval before execution.
        PROMPT
        return base unless @instructions&.match?(/\S/)

        "#{base}\n## Repo-level instructions\n\n#{@instructions.strip}\n"
      end
    end
  end
end
