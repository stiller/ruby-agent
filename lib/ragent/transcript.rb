# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'securerandom'

module Ragent
  class Transcript
    RUNS_DIR = '/tmp/ragent-runs'
    MAX_RESULT_LENGTH = 2000

    attr_reader :run_dir

    def initialize(runs_dir: RUNS_DIR, max_result_length: MAX_RESULT_LENGTH)
      @max_result_length = max_result_length
      slug = "#{Time.now.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(3)}"
      @run_dir = File.join(runs_dir, slug)
      FileUtils.mkdir_p(@run_dir)
      @file = File.open(File.join(@run_dir, 'transcript.jsonl'), 'w')
    end

    def log_prompt(content)
      write(type: 'prompt', content: content)
    end

    def log_model_response(response)
      case response.type
      when 'tool_call'
        write(type: 'tool_call', tool: response.tool, args: response.args)
      when 'final'
        write(type: 'final', content: response.content)
      end
    end

    def log_tool_result(tool, result)
      content = result.to_s
      truncated = content.length > @max_result_length
      write(
        type: 'tool_result',
        tool: tool,
        content: truncated ? content[0, @max_result_length] : content,
        truncated: truncated
      )
    end

    def close
      @file.close
    end

    private

    def write(data)
      @file.puts(JSON.generate(data))
      @file.flush
    end
  end
end
