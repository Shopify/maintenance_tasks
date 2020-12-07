# frozen_string_literal: true

require 'test_helper'

module MaintenanceTasks
  class RunnerTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @name = 'Maintenance::UpdatePostsTask'
      @runner = Runner.new
    end

    test '#run creates and performs a Run for the given Task when there is no active Run' do
      assert_difference -> { Run.where(task_name: @name).count }, 1 do
        assert_enqueued_with(job: MaintenanceTasks.job) do
          assert_equal Maintenance::UpdatePostsTask, @runner.run(name: @name)
        end
      end
    end

    test '#run enqueues the existing active Run for the given Task' do
      run = Run.create!(task_name: @name, status: :paused)

      assert_no_difference -> { Run.where(task_name: @name).count } do
        assert_enqueued_with(job: MaintenanceTasks.job, args: [run]) do
          assert_equal Maintenance::UpdatePostsTask, @runner.run(name: @name)
          assert run.reload.enqueued?
        end
      end
    end

    test '#run raises validation errors' do
      assert_no_difference -> { Run.where(task_name: @name).count } do
        assert_no_enqueued_jobs do
          error = assert_raises(ActiveRecord::RecordInvalid) do
            @runner.run(name: 'Invalid')
          end

          assert_equal(
            'Validation failed: Task name is not included in the list',
            error.message
          )
        end
      end
    end
  end
end
