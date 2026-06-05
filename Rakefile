# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.pattern = 'test/**/test_*.rb'
  t.ruby_opts = ['-r./test/test_helper']
end

task default: :test
