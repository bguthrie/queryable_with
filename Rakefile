require 'rake'
require 'rake/rdoctask'

require 'spec'
require 'spec/rake/spectask'

task :default => :spec

Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--colour', '--format progress', '--backtrace']
end

Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
end
