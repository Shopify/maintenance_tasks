# frozen_string_literal: true

require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test

  setup { Maintenance::UpdatePostsTask.fast_task = false }
  teardown { Maintenance::UpdatePostsTask.fast_task = true }
end
