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

    test '.perform_now exits job when Run is paused' do
      TestTask.any_instance.expects(:process).once.with do
        @run.paused!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test '.perform_now exits job when Run is cancelled' do
      TestTask.any_instance.expects(:process).once.with do
        @run.cancelled!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test '.perform_now skips iterations when Run is paused' do
      @run.paused!

      TestTask.any_instance.expects(:process).never

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test '.perform_now skips iterations when Run is cancelled' do
      @run.cancelled!

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

    test '.perform_now updates tick_total when the job starts' do
      TestTask.any_instance.expects(:process).once.with do
        @run.cancelled!
      end

      TaskJob.perform_now(@run)

      assert_equal 2, @run.reload.tick_total
    end

    test '.perform_now updates Run to running and persists job_id when job starts performing' do
      TestTask.any_instance.expects(:process).twice.with do
        assert_predicate @run.reload, :running?
      end

      job = TaskJob.new(@run)
      job.perform_now

      assert_equal job.job_id, @run.reload.job_id
    end

    test '.perform_now updates Run to succeeded when job finishes successfully' do
      TestTask.any_instance.expects(:process).twice
      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :succeeded?
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

    test '.perform_now updates Run to errored when exception is raised' do
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      TaskJob.perform_now(run)

      run.reload

      assert_predicate run, :errored?
      assert_equal 'ArgumentError', run.error_class
      assert_equal 'Something went wrong', run.error_message
      expected = ["app/tasks/maintenance/error_task.rb:9:in `process'"]
      assert_equal expected, run.backtrace
    end

    test '.perform_now does not enqueue another job if Run errors' do
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      assert_no_enqueued_jobs { TaskJob.perform_now(run) }
    end

    test '.perform_now persists cursor when job shuts down' do
      TestTask.any_instance.expects(:process).once.with do
        @run.paused!
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

    test '.perform_now queries Run status from the db instead of from the query cache' do
      queries = record_uncached_queries do
        ActiveRecord::Base.connection.cache do
          TestTask.any_instance.expects(:process).twice
          TaskJob.perform_now(@run)
        end
      end

      expected_query = /SELECT \"maintenance_tasks_runs\".\"status\"/
      # Expect one query for each iteration of the task job
      # TODO: Update to 2 once
      # https://github.com/Shopify/maintenance_tasks/pull/134 ships
      assert_equal 4, queries.select { |query| query[expected_query] }.size
    end

    private

    def record_uncached_queries(&block)
      queries = []

      query_cb = ->(*, payload) {
        queries << payload.fetch(:sql) unless payload[:cached]
      }
      ActiveSupport::Notifications.subscribed(query_cb,
        'sql.active_record',
        &block)

      queries
    end
  end
end
