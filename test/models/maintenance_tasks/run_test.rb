# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test '#enqueue enqueues the task' do
      assert_enqueued_with job: Maintenance::UpdatePostsTask do
        run = Run.new(task_name: 'Maintenance::UpdatePostsTask')
        run.enqueue
        assert_predicate run, :persisted?
      end
    end

    test '#enqueue performs the task properly' do
      perform_enqueued_jobs do
        run = Run.new(task_name: 'Maintenance::UpdatePostsTask')
        run.enqueue
      end
    end

    test "invalid if the task doesn't exist" do
      run = Run.new(task_name: 'Maintenance::DoesNotExist')
      refute run.valid?
      expected_error = 'Task Maintenance::DoesNotExist does not exist.'
      assert_includes run.errors.full_messages, expected_error
    end

    test 'invalid if the task is abstract' do
      run = Run.new(task_name: 'Maintenance::ApplicationTask')
      refute run.valid?
      expected_error = 'Task Maintenance::ApplicationTask is abstract.'
      assert_includes run.errors.full_messages, expected_error
    end

    test '#increment_ticks persists an increment to the tick count' do
      run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        tick_count: 40,
      )
      run.tick_count = 21
      run.increment_ticks(2)
      assert_equal 21, run.tick_count # record is not used or updated
      assert_equal 42, run.reload.tick_count
    end
  end
end
