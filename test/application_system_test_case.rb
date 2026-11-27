# frozen_string_literal: true

require "test_helper"
require "action_dispatch/system_testing/server"

ActionDispatch::SystemTesting::Server.silence_puma = true

# Necessary so that Capybara::Selenium::DeprecationSuppressor is prepended in
# Selenium::WebDriver::Logger before it is instantiated in
# Selenium::WebDriver.logger to prevent an uninitialized instance variable
# warning in Ruby 2.7.
Capybara::Selenium::Driver.load_selenium

# Capybara 3.40.0 ends ChromeDriver#reset! by clearing storage for the "*" origin, which Chrome 158 rejects with
# "invalid argument: * is not a valid URL", failing every system test in teardown. When Chrome rejects it, clear
# every cookie and the local storage of each origin in the tab's history instead.
# Remove once Capybara releases a fix for https://github.com/teamcapybara/capybara/issues/2865.
if Gem::Version.new(Capybara::VERSION) <= Gem::Version.new("3.40.0")
  module ChromeResetWithoutWildcardOrigin
    private

    def execute_cdp(cmd, params = {})
      super
    rescue Selenium::WebDriver::Error::InvalidArgumentError => error
      raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*" &&
        error.message.include?("is not a valid URL")

      storage_types = params[:storageTypes].to_s.split(",")
      super("Network.clearBrowserCookies") if storage_types.include?("cookies")
      return unless storage_types.include?("local_storage")

      visited_origins.each do |origin|
        super("Storage.clearDataForOrigin", { origin: origin, storageTypes: "local_storage" })
      end
    end

    def visited_origins
      execute_cdp("Page.getNavigationHistory").fetch("entries", []).filter_map { |entry| origin_of(entry["url"]) }.uniq
    end

    def origin_of(url)
      uri = URI.parse(url.to_s)
      return unless ["http", "https"].include?(uri.scheme) && uri.host

      port = ":#{uri.port}" unless uri.port == uri.default_port
      "#{uri.scheme}://#{uri.host}#{port}"
    rescue URI::InvalidURIError
      nil
    end
  end

  Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetWithoutWildcardOrigin)
end

Capybara.configure do |config|
  # This causes flakiness when we're navigating pages because Capybara goes back to the browser to check for the
  # visibility of the node, which doesn't exist anymore:
  #   Selenium::WebDriver::Error::UnknownError: unknown error: unhandled inspector error:
  #   {"code":-32000,"message":"Node with given id does not belong to the document"}
  config.ignore_hidden_elements = false
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
