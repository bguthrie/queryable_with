require 'rake'
require 'rake/rdoctask'

require 'spec'
require 'spec/rake/spectask'

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "queryable_with/version"

task :default => :spec

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--colour', '--format progress', '--backtrace']
end

Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end

namespace :gem do
  task :clean do
    system "rm -f *.gem"
  end
  
  task :build => :clean do
    system "gem build queryable_with.gemspec"
  end
  
  task :release => :build do
    system "gem push queryable_with-#{QueryableWith::VERSION}"
  end
end