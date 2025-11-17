# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fs_layer/version'

Gem::Specification.new do |gem|
  gem.name          = "fs_layer"
  gem.version       = FSLayer::VERSION
  gem.authors       = ["Aldric Giacomoni"]
  gem.email         = ["trevoke@gmail.com"]
  gem.description   = %q{Friendly file/directory interface. Secretary not included.}
  gem.summary       = %q{An interface for files and directories, because using and mocking File/FileUtils is just wrong.}
  gem.homepage      = "https://github.com/Trevoke/fs_layer"
  gem.license       = "MIT"
  gem.required_ruby_version = '>= 2.7.0'

  gem.metadata = {
    "homepage_uri"      => "https://github.com/Trevoke/fs_layer",
    "source_code_uri"   => "https://github.com/Trevoke/fs_layer",
    "bug_tracker_uri"   => "https://github.com/Trevoke/fs_layer/issues",
    "changelog_uri"     => "https://github.com/Trevoke/fs_layer/blob/main/CHANGELOG.md"
  }

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '>= 3.0.0'
  gem.add_development_dependency 'rspec-its', '~> 1.3'
  gem.add_development_dependency 'cucumber'
  gem.add_development_dependency 'simplecov', '~> 0.22'
end
