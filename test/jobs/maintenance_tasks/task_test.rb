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

    test 'can be enqueued without a Run' do
      assert_enqueued_with job: Maintenance::UpdatePostsTask do
        Maintenance::UpdatePostsTask.perform_later
      end
    end

    test 'creates a Run if it has been enqueued without one' do
      assert_difference -> { Run.count } do
        Maintenance::UpdatePostsTask.perform_later
      end
    end

    test 'does not re-enqueue itself if it has been enqueued without a Run' do
      assert_enqueued_jobs 1 do
        Maintenance::UpdatePostsTask.perform_later
      end
    end
  end
end
