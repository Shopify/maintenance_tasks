# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class ApplicationHelperTest < ActionView::TestCase
    test "#time_ago returns a time element with the given datetime worded as relative to now and ISO 8601 UTC time in title attribute" do
      travel_to Time.zone.local(2020, 1, 9, 9, 41, 44)
      time = Time.zone.local(2020, 1, 1, 1, 0, 0)

      expected = '<time datetime="2020-01-01T01:00:00Z" '\
        'title="2020-01-01T01:00:00Z" class="is-clickable">8 days ago</time>'
      assert_equal expected, time_ago(time)
    end
  end
end
