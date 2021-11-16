# frozen_string_literal: true

require "test_helper"
require "webdrivers/chromedriver"
require "action_dispatch/system_testing/server"

ActionDispatch::SystemTesting::Server.silence_puma = true

if Rails::VERSION::MAJOR < 7
  # Necessary so that Capybara::Selenium::DeprecationSuppressor is prepended in
  # Selenium::WebDriver::Logger before it is instantiated in
  # Selenium::WebDriver.logger to prevent an uninitialized instance variable
  # warning.
  Capybara::Selenium::Driver.load_selenium
  Selenium::WebDriver.logger.ignore(:browser_options)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome do |options|
    options.add_argument("--disable-dev-shm-usage")
    options.add_preference(
      :download,
      default_directory: "test/dummy/tmp/downloads"
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
