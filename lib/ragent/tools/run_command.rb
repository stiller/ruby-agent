# frozen_string_literal: true

require 'open3'

module Ragent
  module Tools
    class RunCommand
      MAX_DISPLAY_LINES = 20
      MAX_MODEL_LINES = 50

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

      def initialize(workspace, timeout: 30, output: nil)
        @workspace = workspace
        @timeout = timeout
        @output = output
      end

      def call(command)
        @lines_shown = 0
        @total_lines = 0
        @mutex = Mutex.new
        stdout_str, stderr_str, status = run_with_timeout(command)
        Result.new(command: command, stdout: truncate(stdout_str), stderr: truncate(stderr_str), exit_status: status)
      rescue TimedOut
        Error.new(message: "timed out after #{@timeout}s")
      rescue Errno::ENOENT => e
        Error.new(message: e.message)
      ensure
        finish_streaming
      end

      private

      def run_with_timeout(command)
        Open3.popen3(command, chdir: @workspace) do |_stdin, out, err, wait_thr|
          out_thr = Thread.new { stream_read(out) }
          err_thr = Thread.new { stream_read(err) }
          return [out_thr.value, err_thr.value, wait_thr.value.exitstatus] if wait_thr.join(@timeout)

          kill_process(wait_thr)
          [out_thr, err_thr].each(&:join)
          raise TimedOut
        end
      end

      def stream_read(io)
        buf = +''
        last = nil
        io.each_line do |line|
          buf << line
          show_line(line) unless line == last
          last = line
        end
        buf
      rescue IOError
        buf
      end

      def show_line(line)
        return unless @output

        @mutex.synchronize do
          @total_lines += 1
          next if @lines_shown >= MAX_DISPLAY_LINES

          @output.puts if @lines_shown.zero?
          @output.print Terminal.fmt(line, :dim)
          @lines_shown += 1
        end
      end

      def finish_streaming
        return unless @output && @lines_shown.positive?

        hidden = @total_lines - @lines_shown
        if hidden.positive?
          @output.puts Terminal.fmt("  [#{hidden} more line#{'s' unless hidden == 1} not shown]", :dim)
        end
        @output.puts
      end

      def kill_process(wait_thr)
        Process.kill('KILL', wait_thr.pid)
      rescue Errno::ESRCH
        nil
      ensure
        wait_thr.join
      end

      def truncate(str)
        lines = str.lines
        return str if lines.size <= MAX_MODEL_LINES

        half = MAX_MODEL_LINES / 2
        omitted = lines.size - MAX_MODEL_LINES
        Terminal.debug("output truncated: #{lines.size} lines → #{MAX_MODEL_LINES} shown (#{half} head + #{half} tail)")
        (lines.first(half) + ["[... #{omitted} lines omitted ...]\n"] + lines.last(half)).join
      end
    end
  end
end
