require 'spec'

require 'rake'
require 'spec/rake/spectask'
require 'rcov/rcovtask'

task :default => :spec

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--colour', '--format progress', '--backtrace']
end

Rcov::RcovTask.new do |t|
  t.pattern = "spec/**/_spec.rb"
  t.rcov_opts = [ "--spec-only" ]
  t.output_dir = "coverage"
end
