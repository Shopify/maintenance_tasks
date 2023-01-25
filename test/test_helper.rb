# frozen_string_literal: true

# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths =
  [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths <<
  File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require "mocha/minitest"

Mocha.configure do |c|
  c.display_matching_invocations_on_failure = true
  c.stubbing_method_on_non_mock_object      = :allow
  c.stubbing_method_unnecessarily           = :prevent
  c.stubbing_non_existent_method            = :prevent
  c.stubbing_non_public_method              = :prevent
end

# Filter out the backtrace from minitest while preserving the one from other
# libraries.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("fixtures", __dir__)
  ActionDispatch::IntegrationTest.fixture_path =
    ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path =
    ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures(:all)
end

# CSV 3.2.1 changes $stderr to see if $INPUT_RECORD_SEPARATOR is deprecated, so
# we require it before to avoid that deprecation from raising.
require "csv"

module Warning
  class << self
    def warn(message)
      raise message.to_s
    end
  end
end
$VERBOSE = true
Warning[:deprecated] = true

Maintenance::UpdatePostsTask.fast_task = true
