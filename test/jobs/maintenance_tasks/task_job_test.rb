# frozen_string_literal: true
require 'test_helper'
require 'job-iteration'

module MaintenanceTasks
  class TaskJobTest < ActiveJob::TestCase
    class TestTask < Task
      def collection
        [1, 2]
      end

      def count
        collection.count
      end
    end

    setup do
      @run = Run.create!(task_name: 'MaintenanceTasks::TaskJobTest::TestTask')
    end

    test '.perform_now exits job when Run is paused, and updates Run status from pausing to paused' do
      TestTask.any_instance.expects(:process).once.with do
        @run.pausing!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test '.perform_now exits job when Run is cancelled, and updates Run status from cancelling to cancelled' do
      TestTask.any_instance.expects(:process).once.with do
        @run.cancelling!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test '.perform_now persists ended_at when the Run is cancelled' do
      freeze_time
      TestTask.any_instance.expects(:process).once.with do
        @run.cancelling!
      end

      TaskJob.perform_now(@run)

      assert_equal Time.now, @run.reload.ended_at
    end

    test '.perform_now skips iterations when Run is paused' do
      @run.pausing!

      TestTask.any_instance.expects(:process).never

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test '.perform_now skips iterations when Run is cancelled' do
      @run.cancelling!

      TestTask.any_instance.expects(:process).never

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test '.perform_now updates tick_count' do
      TestTask.any_instance.expects(:process).twice

      TaskJob.perform_now(@run)

      assert_equal 2, @run.reload.tick_count
    end

    test '.perform_now updates tick_count when job is interrupted' do
      JobIteration.stubs(interruption_adapter: -> { true })
      TestTask.any_instance.expects(:process).once

      TaskJob.perform_now(@run)

      assert_equal 1, @run.reload.tick_count
    end

    test '.perform_now persists started_at and updates tick_total when the job starts' do
      freeze_time
      TestTask.any_instance.expects(:process).once.with do
        @run.cancelling!
      end

      TaskJob.perform_now(@run)

      assert_equal Time.now, @run.reload.started_at
      assert_equal 2, @run.tick_total
    end

    test '.perform_now updates Run to running and persists job_id when job starts performing' do
      TestTask.any_instance.expects(:process).twice.with do
        assert_predicate @run.reload, :running?
      end

      job = TaskJob.new(@run)
      job.perform_now

      assert_equal job.job_id, @run.reload.job_id
    end

    test '.perform_now updates Run to succeeded and persists ended_at when job finishes successfully' do
      freeze_time
      TestTask.any_instance.expects(:process).twice
      TaskJob.perform_now(@run)

      assert_equal Time.now, @run.reload.ended_at
      assert_predicate @run, :succeeded?
    end

    test '.perform_now updates Run to interrupted when job is interrupted' do
      JobIteration.stubs(interruption_adapter: -> { true })
      TestTask.any_instance.expects(:process).once

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :interrupted?
    end

    test '.perform_now re-enqueues the job when interrupted' do
      JobIteration.stubs(interruption_adapter: -> { true })
      TestTask.any_instance.expects(:process).once

      assert_enqueued_with(job: TaskJob) { TaskJob.perform_now(@run) }
    end

    test '.perform_now updates Run to errored and persists ended_at when exception is raised' do
      freeze_time
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      TaskJob.perform_now(run)

      run.reload

      assert_predicate run, :errored?
      assert_equal 'ArgumentError', run.error_class
      assert_equal 'Something went wrong', run.error_message
      expected = ["app/tasks/maintenance/error_task.rb:9:in `process'"]
      assert_equal expected, run.backtrace
      assert_equal Time.now, run.ended_at
    end

    test '.perform_now does not enqueue another job if Run errors' do
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      assert_no_enqueued_jobs { TaskJob.perform_now(run) }
    end

    test '.perform_now updates tick_count when job is errored' do
      TestTask.any_instance.expects(:process).twice
        .returns(nil)
        .raises(ArgumentError)

      TaskJob.perform_now(@run)

      assert_equal 1, @run.reload.tick_count
    end

    test '.perform_now persists cursor when job shuts down' do
      TestTask.any_instance.expects(:process).once.with do
        @run.pausing!
      end

      TaskJob.perform_now(@run)

      assert_equal 0, @run.reload.cursor
    end

    test '.perform_now starts job from cursor position when job resumes' do
      @run.update!(cursor: 0)

      TestTask.any_instance.expects(:process).once.with(2)

      TaskJob.perform_now(@run)
    end

    test '.perform_now accepts Active Record Relations as collection' do
      TestTask.any_instance.stubs(collection: Post.all)
      TestTask.any_instance.expects(:process).times(Post.count)

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :succeeded?
    end

    test '.perform_now sets the Run as errored when the Task collection is invalid' do
      TestTask.any_instance.stubs(collection: 'not a collection')

      TaskJob.perform_now(@run)
      @run.reload

      assert_predicate @run, :errored?
      assert_equal 'ArgumentError', @run.error_class
      assert_empty @run.backtrace
      expected_message = 'MaintenanceTasks::TaskJobTest::TestTask#collection '\
        'must be either an Active Record Relation or an Array.'
      assert_equal expected_message, @run.error_message
    end

    test '.retry_on raises NotImplementedError' do
      assert_raises NotImplementedError do
        Class.new(TaskJob) { retry_on StandardError }
      end
    end

    test '.perform_now calls the error handler when there was an Error' do
      error_handler_before = MaintenanceTasks.error_handler
      handled_error = nil
      MaintenanceTasks.error_handler = ->(error) { handled_error = error }
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      TaskJob.perform_now(run)

      assert_equal(ArgumentError, handled_error.class)
    ensure
      MaintenanceTasks.error_handler = error_handler_before
    end

    test '.perform_now still persists the error properly if the error handler raises' do
      error_handler_before = MaintenanceTasks.error_handler
      MaintenanceTasks.error_handler = ->(error) { raise error }
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      assert_raises { TaskJob.perform_now(run) }
      run.reload

      assert_predicate(run, :errored?)
      assert_equal(1, run.tick_count)
    ensure
      MaintenanceTasks.error_handler = error_handler_before
    end
  end
end
