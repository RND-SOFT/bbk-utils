# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

Bundler::GemHelper.install_tasks

task default: :spec

namespace :bbk do
  namespace :utils do
    desc "Generate documentation for environment variables (options: CONFIG=./.env_docs.yml, OUTPUT=./env_docs.md)"
    task :docs do
      args = []
      args.concat(['-c', ENV['CONFIG']]) if ENV['CONFIG']
      args.concat(['-o', ENV['OUTPUT']]) if ENV['OUTPUT']
  
     sh "ruby", "bin/env_docs", *args
     end
  end
end