# frozen_string_literal: true

require 'test_helper'

module MaintenanceTasks
  class RunnerTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @name = 'Maintenance::UpdatePostsTask'
      @runner = Runner
      @job = MaintenanceTasks.job.constantize
    end

    test '#run creates and performs a Run for the given Task when there is no active Run' do
      assert_difference -> { Run.where(task_name: @name).count }, 1 do
        assert_enqueued_with(job: @job) do
          assert_equal Maintenance::UpdatePostsTask, @runner.run(name: @name)
        end
      end
    end

    test '#run enqueues the existing active Run for the given Task' do
      run = Run.create!(task_name: @name, status: :paused)

      assert_no_difference -> { Run.where(task_name: @name).count } do
        assert_enqueued_with(job: @job, args: [run]) do
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

    test '#run raises enqueuing errors if enqueuing raises' do
      @job.expects(:perform_later).raises(RuntimeError, 'error')
      assert_no_enqueued_jobs do
        error = assert_raises(Runner::EnqueuingError) do
          @runner.run(name: @name)
        end

        assert_equal(
          "The job to perform #{@name} could not be enqueued",
          error.message
        )
        assert_kind_of RuntimeError, error.cause
        assert_equal 'error', error.cause.message
      end
    end

    test '#run raises enqueuing errors if enqueuing is unsuccessful' do
      @job.expects(:perform_later).returns(false)
      assert_no_enqueued_jobs do
        error = assert_raises(Runner::EnqueuingError) do
          @runner.run(name: @name)
        end

        assert_equal(
          "The job to perform #{@name} could not be enqueued",
          error.message
        )
        assert_kind_of RuntimeError, error.cause
        assert_equal(
          "The job to perform #{@name} could not be enqueued. "\
          'Enqueuing has been prevented by a callback.',
          error.cause.message
        )
      end
    end
  end
end
