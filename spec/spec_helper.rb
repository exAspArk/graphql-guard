# frozen_string_literal: true

require "bundler/setup"

ENV['GRAPHQL_RUBY_VERSION'] ||= '1_8'

if ENV['CI']
  require 'simplecov'
  SimpleCov.add_filter('spec')
  require 'coveralls'
  Coveralls.wear!
end

require "graphql/guard"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
