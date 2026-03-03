require 'rake'

namespace :bbk do
  namespace :utils do
    desc "Generate documentation for environment variables (options: BBKDOCS_CONFIG=./.bbkdocs.yml, BBKDOCS_OUTPUT=./bbkdocs.md, BBKDOCS_CATEGORIES=./bbkdocs.json)"
    task :docs do
      args = []
      args.concat(['-c', ENV['BBKDOCS_CONFIG']]) if ENV['BBKDOCS_CONFIG']
      args.concat(['-o', ENV['BBKDOCS_OUTPUT']]) if ENV['BBKDOCS_OUTPUT']
      args.concat(['-g', ENV['BBKDOCS_CATEGORIES']]) if ENV['BBKDOCS_CATEGORIES']
  
      sh "ruby", "bin/bbkdocs", *args
    end
  end
end

