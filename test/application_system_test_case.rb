# frozen_string_literal: true

require 'test_helper'
require 'webdrivers/chromedriver'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome do |options|
    options.add_argument('--disable-dev-shm-usage')
  end

  setup do
    travel_to Time.zone.local(2020, 01, 01, 01, 00, 00)
    Maintenance::UpdatePostsTask.fast_task = false
  end

  teardown { Maintenance::UpdatePostsTask.fast_task = true }
end
