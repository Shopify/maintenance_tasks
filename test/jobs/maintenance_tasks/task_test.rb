# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test '.descendants returns list of tasks that inherit from the Task superclass' do
      expected_tasks = [Maintenance::UpdatePostsTask]
      assert_equal expected_tasks, MaintenanceTasks::Task.descendants
    end

    test 'can be enqueued without a Run' do
      assert_enqueued_with job: Maintenance::UpdatePostsTask do
        Maintenance::UpdatePostsTask.perform_later
      end
    end

    test 'creates a Run if it has been enqueued without one' do
      assert_changes -> { Run.count } do
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
