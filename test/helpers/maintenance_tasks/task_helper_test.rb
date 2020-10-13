# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskHelperTest < ActionView::TestCase
    test '#format_backtrace converts the backtrace to a formatted string' do
      backtrace = [
        "app/jobs/maintenance/error_task.rb:13:in `foo'",
        "app/jobs/maintenance/error_task.rb:9:in `task_iteration'",
      ]

      expected_trace = 'app/jobs/maintenance/error_task.rb:13:in `foo&#39;' \
        '<br>app/jobs/maintenance/error_task.rb:9:in `task_iteration&#39;'

      assert_equal expected_trace, format_backtrace(backtrace)
    end
  end
end
