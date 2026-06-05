# frozen_string_literal: true

require 'open3'

module Ragent
  module Tools
    class RunCommand
      MAX_OUTPUT = 50 * 1024

      Result = Struct.new(:command, :stdout, :stderr, :exit_status, keyword_init: true) do
        def to_s
          parts = ["Exit status: #{exit_status}"]
          parts << "stdout:\n#{stdout}" unless stdout.empty?
          parts << "stderr:\n#{stderr}" unless stderr.empty?
          parts.join("\n")
        end
      end

      Error = Struct.new(:message, keyword_init: true) do
        def to_s
          "Command error: #{message}"
        end
      end

      class TimedOut < StandardError; end

      def initialize(workspace, timeout: 30)
        @workspace = workspace
        @timeout = timeout
      end

      def call(command)
        stdout_str, stderr_str, status = run_with_timeout(command)
        Result.new(command: command, stdout: truncate(stdout_str), stderr: truncate(stderr_str), exit_status: status)
      rescue TimedOut
        Error.new(message: "timed out after #{@timeout}s")
      rescue Errno::ENOENT => e
        Error.new(message: e.message)
      end

      private

      def run_with_timeout(command)
        Open3.popen3(command, chdir: @workspace) do |_stdin, out, err, wait_thr|
          out_thr = Thread.new { out.read }
          err_thr = Thread.new { err.read }
          return [out_thr.value, err_thr.value, wait_thr.value.exitstatus] if wait_thr.join(@timeout)

          kill_process(wait_thr)
          [out_thr, err_thr].each(&:join)
          raise TimedOut
        end
      end

      def kill_process(wait_thr)
        Process.kill('KILL', wait_thr.pid)
      rescue Errno::ESRCH
        nil
      ensure
        wait_thr.join
      end

      def truncate(str)
        return str if str.bytesize <= MAX_OUTPUT

        "#{str.byteslice(0, MAX_OUTPUT)}\n[output truncated]"
      end
    end
  end
end
