# frozen_string_literal: true

require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper

  driven_by :rack_test

  setup do
    travel_to Time.zone.local(2020, 01, 01, 01, 00, 00)
    Maintenance::UpdatePostsTask.fast_task = false
  end
  teardown { Maintenance::UpdatePostsTask.fast_task = true }
end
