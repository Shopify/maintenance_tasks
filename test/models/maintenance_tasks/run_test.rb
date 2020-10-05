# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test 'a Run can be persisted with a task' do
      assert_changes -> { Run.count } do
        Run.create(task_name: 'Maintenance::UpdatePostsTask')
      end
    end

    test 'creating a Run enqueues the task' do
      assert_enqueued_with job: Maintenance::UpdatePostsTask do
        assert_not_nil Run.create(task_name: 'Maintenance::UpdatePostsTask')
      end
    end

    test "a Run is invalid if the task doesn't exist" do
      run = Run.new(task_name: 'Maintenance::DoesNotExist')
      refute run.valid?
      refute_empty run.errors
    end
  end
end
