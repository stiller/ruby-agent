# frozen_string_literal: true

require 'tempfile'
require 'open3'

module Ragent
  class UnifiedDiff
    HEADER = /\A--- .*\n\+\+\+ .*\n/

    def self.compute(path, old_content, new_content)
      Tempfile.open(['ragent-old', '.txt']) do |old_tmp|
        Tempfile.open(['ragent-new', '.txt']) do |new_tmp|
          old_tmp.write(old_content)
          old_tmp.flush
          new_tmp.write(new_content)
          new_tmp.flush
          diff, = Open3.capture2('diff', '-u', old_tmp.path, new_tmp.path)
          relabel(diff, path)
        end
      end
    end

    def self.relabel(diff, path)
      rel = path.to_s
      diff.sub(HEADER, "--- a/#{rel}\n+++ b/#{rel}\n")
    end
    private_class_method :relabel
  end
end
