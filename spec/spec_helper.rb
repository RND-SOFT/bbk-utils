ENV['RAILS_ENV'] ||= 'test'

require 'simplecov'
require 'simplecov-console'
require 'simplecov-cobertura'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                 SimpleCov::Formatter::HTMLFormatter, # for gitlab
                                                                 SimpleCov::Formatter::Console, # for developers
                                                                 SimpleCov::Formatter::CoberturaFormatter # for gitlab Cobertura
                                                               ])

SimpleCov.start

require 'bundler'
require 'bundler/setup'
Bundler.require(:default, :development, :test)

BBK::Utils.logger = ::Logger.new(IO::NULL)

$root = File.join(File.dirname(__dir__), 'spec')
Dir[File.join(__dir__, 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
