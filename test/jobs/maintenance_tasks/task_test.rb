# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveJob::TestCase
    class ExampleTask < Task
      self.abstract_class = true

      attr_reader :task_enumerator_called
      attr_reader :task_enumerator_cursor
      attr_reader :task_iteration_called
      attr_reader :task_iteration_argument

      def task_enumerator(cursor:)
        @task_enumerator_called = true
        @task_enumerator_cursor = cursor
      end

      def task_iteration(argument)
        @task_iteration_called = true
        @task_iteration_argument = argument
      end
    end

    class SnapshotTask < Task
      self.abstract_class = true

      attr_reader :run

      class << self
        attr_reader :run_status_snapshots

        def clear
          @run_status_snapshots = []
        end
      end

      private

      def job_running
        super
        self.class.run_status_snapshots << run.status
      end

      def job_completed
        super
        self.class.run_status_snapshots << run.status
      end

      def reenqueue_iteration_job
        super
        self.class.run_status_snapshots << run.status
      end
    end

    class SuccessfulJob < SnapshotTask
      def task_enumerator(*)
        [1].to_enum
      end

      def task_iteration(*); end
    end

    class InterruptedJob < SnapshotTask
      def task_enumerator(*)
        [1, 2].to_enum
      end

      def task_iteration(*); end

      def job_should_exit?
        true if executions == 1
      end
    end

    def setup
      SuccessfulJob.clear
      InterruptedJob.clear
    end

    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = [
        'Maintenance::UpdatePostsTask',
        'MaintenanceTasks::TaskTest::InterruptedJob',
        'MaintenanceTasks::TaskTest::SuccessfulJob',
      ]
      assert_equal expected,
        MaintenanceTasks::Task.available_tasks.map(&:name).sort
    end

    test '.named returns the task based on its name' do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named('Maintenance::UpdatePostsTask')
    end

    test ".named returns nil if the task doesn't exist" do
      assert_nil Task.named('Maintenance::DoesNotExist')
    end

    test '#build_enumerator calls task_enumerator' do
      task = ExampleTask.new
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')
      task.send(:build_enumerator, run, cursor: :some_cursor)
      assert(task.task_enumerator_called)
      assert_equal(:some_cursor, task.task_enumerator_cursor)
    end

    test '#each_iteration calls .task_iteration' do
      task = ExampleTask.new
      run = nil
      task.send(:each_iteration, :some_record, run)
      assert(task.task_iteration_called)
      assert_equal(:some_record, task.task_iteration_argument)
    end

    test 'updates associated Run to running and persists job_id when job starts performing' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::SuccessfulJob')
      job = SuccessfulJob.perform_later(run)

      perform_enqueued_jobs

      run.reload
      assert_equal job.job_id, run.job_id

      assert_includes SuccessfulJob.run_status_snapshots, 'running'
    end

    test 'updates associated Run to succeeded when job finishes successfully' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::SuccessfulJob')
      SuccessfulJob.perform_later(run)

      perform_enqueued_jobs

      assert_includes SuccessfulJob.run_status_snapshots, 'succeeded'
    end

    test 'updates associated Run to interrupted when job is interrupted' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::InterruptedJob')
      InterruptedJob.perform_later(run)

      perform_enqueued_jobs

      assert_includes InterruptedJob.run_status_snapshots, 'interrupted'
    end

    test 'job is reenqueued if interrupted' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::InterruptedJob')
      InterruptedJob.perform_later(run)

      perform_enqueued_jobs

      assert_includes InterruptedJob.run_status_snapshots, 'succeeded'
    end
  end
end
