# frozen_string_literal: true

# Stub pigpio require for tests (not available without hardware)
require 'kernel' unless defined?(Kernel)
module Kernel
  alias original_require require

  def require(name)
    return true if name == 'pigpio'

    original_require(name)
  end
end

# Define Pigpio module and classes before application code loads
module Pigpio
  module Constant
    PI_OUTPUT = 1
    PI_PUD_OFF = 0
  end

  module IF
    class GPIO
      attr_accessor :mode, :pud

      def write(_value); end
    end
  end

  # Main Pigpio class accessible via Pigpio.new
  def self.new
    PigpioInstance.new
  end

  class PigpioInstance
    def connect # rubocop:disable Naming/PredicateMethod
      true
    end

    def gpio(_pin_number)
      IF::GPIO.new
    end

    def stop; end
  end
end

require 'simplecov'
require 'simplecov-console'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'

  add_group 'App', 'app'
  add_group 'Models', 'app/models'
  add_group 'Services', 'app/services'
  add_group 'Helpers', 'app/helpers'
  add_group 'Libraries', 'lib'

  minimum_coverage 95
  minimum_coverage_by_file 85

  formatter SimpleCov::Formatter::MultiFormatter.new([
                                                       SimpleCov::Formatter::HTMLFormatter,
                                                       SimpleCov::Formatter::Console
                                                     ])
end

ENV['RACK_ENV'] = 'test'

require 'bundler/setup'
require 'rspec'
require 'rack/test'
require 'timecop'
require 'pry'

# Load support files
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = false

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Clean up Timecop after each test
  config.after do
    Timecop.return
  end
end
