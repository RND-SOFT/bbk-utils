lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "aggredator/version"

Gem::Specification.new do |spec|
  spec.name          = "aggredator-utils"
  spec.version       = Aggredator::Utils::VERSION
  spec.authors       = ["Samoilenko Yuri"]
  spec.email         = ["kinnalru@gmail.com"]

  spec.summary       = 'Support classes for aggredator services'
  spec.description   = 'Support classes for aggredator services'

  spec.files         = Dir['bin/*', 'lib/**/*', "Gemfile*", "LICENSE.txt", "README.md"] 
  spec.bindir        = 'bin'
  spec.require_paths = ['lib']

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activesupport'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-console'
  spec.add_development_dependency 'rubycritic'
  spec.add_development_dependency 'faker', '~> 2.4'
end
