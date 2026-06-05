# frozen_string_literal: true

require 'open3'

module Ragent
  class RunSummary
    MAX_DIFF_SIZE = 8000

    def initialize(workspace, model_client: nil)
      @workspace = workspace
      @model_client = model_client
    end

    def call(original_prompt)
      return nil unless git_repo?

      stat = diff_stat.strip
      return nil if stat.empty?

      parts = ["Changed:\n#{stat}"]
      model_text = model_summary(original_prompt) if @model_client
      parts << "\n#{model_text}" if model_text
      parts.join("\n")
    end

    def git_repo?
      _, st = Open3.capture2e('git', '-C', @workspace, 'rev-parse', '--git-dir')
      st.success?
    end

    private

    def diff_stat
      out, = Open3.capture2e('git', '-C', @workspace, 'diff', '--stat', 'HEAD')
      out
    end

    def diff
      out, = Open3.capture2e('git', '-C', @workspace, 'diff', 'HEAD')
      out.length > MAX_DIFF_SIZE ? "#{out[0, MAX_DIFF_SIZE]}\n... (truncated)" : out
    end

    def model_summary(original_prompt)
      response = @model_client.call([{ role: 'user', content: summary_prompt(original_prompt, diff) }])
      response.content
    rescue StandardError
      nil
    end

    def summary_prompt(original_prompt, diff_content)
      <<~PROMPT.strip
        Task: #{original_prompt}

        Git diff of changes made:
        #{diff_content}

        Write a brief summary (3–5 bullets) covering:
        - What changed and why
        - Tests run (if any)
        - Remaining risks or follow-up items
      PROMPT
    end
  end
end
