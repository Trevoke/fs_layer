# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cabinet/version'

Gem::Specification.new do |gem|
  gem.name          = "cabinet"
  gem.version       = Cabinet::VERSION
  gem.authors       = ["Aldric Giacomoni"]
  gem.email         = ["trevoke@gmail.com"]
  gem.description   = %q{Friendly file/directory interface. Secretary not included.}
  gem.summary       = %q{An interface for files and directories, because using and mocking File/FileUtils is just wrong.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '>= 2.12.0'
  gem.add_development_dependency 'cucumber'
end
