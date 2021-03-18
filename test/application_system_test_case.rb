# frozen_string_literal: true

require "test_helper"
require "webdrivers/chromedriver"
require "action_dispatch/system_testing/server"

ActionDispatch::SystemTesting::Server.silence_puma = true

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
    Maintenance::UpdatePostsTask.fast_task = false
  end

  teardown do
    assert_empty page.driver.browser.manage.logs.get(:browser)
    Maintenance::UpdatePostsTask.fast_task = true
    FileUtils.rm_rf("test/dummy/tmp/downloads")
  end
end
