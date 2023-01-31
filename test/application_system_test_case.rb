# frozen_string_literal: true

require "test_helper"
require "webdrivers/chromedriver"
require "selenium/webdriver/remote/commands"
require "action_dispatch/system_testing/server"

ActionDispatch::SystemTesting::Server.silence_puma = true

# Necessary so that Capybara::Selenium::DeprecationSuppressor is prepended in
# Selenium::WebDriver::Logger before it is instantiated in
# Selenium::WebDriver.logger to prevent an uninitialized instance variable
# warning in Ruby 2.7.
Capybara::Selenium::Driver.load_selenium

if Rails::VERSION::MAJOR < 7
  Selenium::WebDriver.logger.ignore(:browser_options)
elsif Rails.gem_version < Gem::Version.new("7.1")
  Selenium::WebDriver.logger.ignore(:capabilities)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome do |options|
    options.add_argument("--disable-dev-shm-usage")
    options.add_preference(
      :download,
      default_directory: "test/dummy/tmp/downloads",
    )
  end

  setup do
    travel_to Time.zone.local(2020, 1, 9, 9, 41, 44)
  end

  teardown do
    assert_empty page.driver.browser.logs.get(:browser)
    FileUtils.rm_rf("test/dummy/tmp/downloads")
  end
end
