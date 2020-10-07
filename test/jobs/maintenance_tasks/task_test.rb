# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveJob::TestCase
    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = ['Maintenance::UpdatePostsTask']
      assert_equal expected, MaintenanceTasks::Task.available_tasks.map(&:name)
    end

    test '.named returns the task based on its name' do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named('Maintenance::UpdatePostsTask')
    end

    test ".named returns nil if the task doesn't exist" do
      assert_nil Task.named('Maintenance::DoesNotExist')
    end
  end
end
