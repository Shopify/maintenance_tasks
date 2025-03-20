# frozen_string_literal: true

require "test_helper"
require "action_dispatch/system_testing/server"

ActionDispatch::SystemTesting::Server.silence_puma = true

# Necessary so that Capybara::Selenium::DeprecationSuppressor is prepended in
# Selenium::WebDriver::Logger before it is instantiated in
# Selenium::WebDriver.logger to prevent an uninitialized instance variable
# warning in Ruby 2.7.
Capybara::Selenium::Driver.load_selenium

Capybara.configure do |config|
  # This causes flakiness when we're navigating pages because Capybara goes back to the browser to check for the
  # visibility of the node, which doesn't exist anymore:
  #   Selenium::WebDriver::Error::UnknownError: unknown error: unhandled inspector error:
  #   {"code":-32000,"message":"Node with given id does not belong to the document"}
  config.ignore_hidden_elements = false
end

if Rails.gem_version < Gem::Version.new("7.1")
  Selenium::WebDriver.logger.ignore(:capabilities)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome do |options|
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--headless=new")
    options.add_argument("--disable-gpu")
  end

  setup do
    travel_to Time.zone.local(2020, 1, 9, 9, 41, 44)
    page.driver.browser.download_path = "test/dummy/tmp/downloads"
    unless page.driver.invalid_element_errors.include?(Selenium::WebDriver::Error::UnknownError)
      page.driver.invalid_element_errors << Selenium::WebDriver::Error::UnknownError
    end
  end

  teardown do
    assert_empty page.driver.browser.logs.get(:browser)
    FileUtils.rm_rf("test/dummy/tmp/downloads")
  end
end
