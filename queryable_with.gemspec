# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'queryable_with/version'
 
Gem::Specification.new do |s|
  s.name        = "queryable_with"
  s.version     = QueryableWith::Version::STRING
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Brian Guthrie"]
  s.email       = ["btguthrie@gmail.com"]
  s.homepage    = "http://github.com/bguthrie/queryable_with"
  s.summary     = "An ActiveRecord library for creating reusable sets of scopes."
  s.description = "Tie query parameters to scopes, or create dynamic scopes on the fly. Define sets of reusable scopes for use in reporting and filtering."
  
  s.add_dependency 'activerecord', '>= 2.3.0'
  s.add_development_dependency "rspec"
  
  s.files = Dir.glob("lib/**/*") + %w(README.rdoc CHANGELOG Rakefile)
  s.test_files = Dir.glob("spec/**/*")
 
  s.require_path = 'lib'
end