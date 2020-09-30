# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test '.enqueue_task_named enqueues the task' do
      assert_enqueued_with job: Maintenance::UpdatePostsTask do
        assert_not_nil Run.enqueue_task_named('Maintenance::UpdatePostsTask')
      end
    end

    test ".enqueue_task_named returns nil if the task doesn't exist" do
      assert_nil Run.enqueue_task_named('Maintenance::DoesNotExist')
    end
  end
end
