# frozen_string_literal: true

require 'test_helper'
require 'webdrivers/chromedriver'

Capybara.server = :puma, { Silent: true, environment: 'test' }

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome do |options|
    options.add_argument('--disable-dev-shm-usage')
  end

  setup do
    travel_to Time.zone.local(2020, 1, 9, 9, 41, 44)
    Maintenance::UpdatePostsTask.fast_task = false
  end

  teardown do
    assert_empty page.driver.browser.manage.logs.get(:browser)
    Maintenance::UpdatePostsTask.fast_task = true
  end
end
