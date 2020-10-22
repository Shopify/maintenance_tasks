# frozen_string_literal: true
require 'test_helper'
require 'job-iteration'

module MaintenanceTasks
  class TaskJobTest < ActiveJob::TestCase
    class TestTask < Task
      def task_enumerator(cursor:)
        enumerator_builder.build_array_enumerator(
          [1, 2],
          cursor: cursor
        )
      end

      def task_count
        2
      end
    end

    setup do
      @run = Run.create!(task_name: 'MaintenanceTasks::TaskJobTest::TestTask')
    end

    test '.perform_now exits job when Run is paused' do
      TestTask.any_instance.expects(:task_iteration).once.with do
        @run.paused!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test '.perform_now exits job when Run is cancelled' do
      TestTask.any_instance.expects(:task_iteration).once.with do
        @run.cancelled!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test '.perform_now skips iterations when Run is paused' do
      @run.paused!

      TestTask.any_instance.expects(:task_iteration).never

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test '.perform_now skips iterations when Run is cancelled' do
      @run.cancelled!

      TestTask.any_instance.expects(:task_iteration).never

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test '.perform_now updates tick_count' do
      TestTask.any_instance.expects(:task_iteration).twice

      TaskJob.perform_now(@run)

      assert_equal 2, @run.reload.tick_count
    end

    test '.perform_now updates tick_count when job is interrupted' do
      JobIteration.stubs(interruption_adapter: -> { true })
      TestTask.any_instance.expects(:task_iteration).once

      TaskJob.perform_now(@run)

      assert_equal 1, @run.reload.tick_count
    end

    test '.perform_now updates tick_total when the job starts' do
      TestTask.any_instance.expects(:task_iteration).once.with do
        @run.cancelled!
      end

      TaskJob.perform_now(@run)

      assert_equal 2, @run.reload.tick_total
    end

    test '.perform_now updates Run to running and persists job_id when job starts performing' do
      TestTask.any_instance.expects(:task_iteration).twice.with do
        assert_predicate @run.reload, :running?
      end

      job = TaskJob.new(@run)
      job.perform_now

      assert_equal job.job_id, @run.reload.job_id
    end

    test '.perform_now updates Run to succeeded when job finishes successfully' do
      TestTask.any_instance.expects(:task_iteration).twice
      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :succeeded?
    end

    test '.perform_now updates Run to interrupted when job is interrupted' do
      JobIteration.stubs(interruption_adapter: -> { true })
      TestTask.any_instance.expects(:task_iteration).once

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :interrupted?
    end

    test '.perform_now re-enqueues the job when interrupted' do
      JobIteration.stubs(interruption_adapter: -> { true })
      TestTask.any_instance.expects(:task_iteration).once

      assert_enqueued_with(job: TaskJob) { TaskJob.perform_now(@run) }
    end

    test '.perform_now updates Run to errored when exception is raised' do
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      TaskJob.perform_now(run)

      run.reload

      assert_predicate run, :errored?
      assert_equal 'ArgumentError', run.error_class
      assert_equal 'Something went wrong', run.error_message
      expected = ["app/tasks/maintenance/error_task.rb:9:in `task_iteration'"]
      assert_equal expected, run.backtrace
    end

    test '.perform_now does not enqueue another job if Run errors' do
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      assert_no_enqueued_jobs { TaskJob.perform_now(run) }
    end

    test '.perform_now persists cursor when job shuts down' do
      TestTask.any_instance.expects(:task_iteration).once.with do
        @run.paused!
      end

      TaskJob.perform_now(@run)

      assert_equal 0, @run.reload.cursor
    end

    test '.perform_now starts job from cursor position when job resumes' do
      @run.update!(cursor: 0)

      TestTask.any_instance.expects(:task_iteration).once.with(2)

      TaskJob.perform_now(@run)
    end
  end
end
