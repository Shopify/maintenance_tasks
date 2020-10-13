# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveJob::TestCase
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

      def shutdown_job
        super
        self.class.run_status_snapshots << run.status
      end
    end

    class SuccessfulTask < SnapshotTask
      def task_enumerator(*)
        [1].to_enum
      end

      def task_iteration(*); end
    end

    class InterruptedTask < SnapshotTask
      def task_enumerator(*)
        [1, 2].to_enum
      end

      def task_iteration(*); end

      def job_should_exit?
        true if executions == 1
      end
    end

    class PausedTask < SnapshotTask
      def task_enumerator(*)
        [1, 2, 3, 4].to_enum
      end

      def task_iteration(*)
        @run.paused!
      end
    end

    def setup
      PausedTask.clear
      SuccessfulTask.clear
      InterruptedTask.clear
    end

    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = [
        'Maintenance::UpdatePostsTask',
        'MaintenanceTasks::TaskTest::InterruptedTask',
        'MaintenanceTasks::TaskTest::PausedTask',
        'MaintenanceTasks::TaskTest::SuccessfulTask',
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

    test '.perform_now exits job when Run is paused' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::PausedTask')

      PausedTask.perform_now(run)

      assert_equal ['running', 'paused'], PausedTask.run_status_snapshots
      assert_predicate run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test 'updates associated Run to running and persists job_id when job starts performing' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::SuccessfulTask')
      job = SuccessfulTask.new(run)
      job.perform_now

      assert_equal job.job_id, run.job_id
      assert_includes SuccessfulTask.run_status_snapshots, 'running'
    end

    test 'updates associated Run to succeeded when job finishes successfully' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::SuccessfulTask')
      SuccessfulTask.perform_now(run)

      assert_predicate run.reload, :succeeded?
    end

    test 'updates associated Run to interrupted when job is interrupted' do
      run = Run.create!(
        task_name: 'MaintenanceTasks::TaskTest::InterruptedTask'
      )
      InterruptedTask.perform_now(run)

      assert_predicate run.reload, :interrupted?
    end

    test 'job is reenqueued if interrupted' do
      run = Run.create!(
        task_name: 'MaintenanceTasks::TaskTest::InterruptedTask'
      )

      assert_enqueued_with job: InterruptedTask do
        InterruptedTask.perform_now(run)
      end
    end

      perform_enqueued_jobs

      assert_includes InterruptedJob.run_status_snapshots, 'succeeded'
    end
  end
end
