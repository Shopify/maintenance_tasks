# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    test '.task_named returns the task based on its name' do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named('Maintenance::UpdatePostsTask')
    end

    test ".task_named returns nil if the task doesn't exist" do
      assert_nil Task.named('Maintenance::DoesNotExist')
    end
  end
end
