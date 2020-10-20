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

    class CancelledTask < SnapshotTask
      def task_enumerator(*)
        [1, 2].to_enum
      end

      def task_iteration(*)
        @run.cancelled!
      end
    end

    class ControlledTask < SnapshotTask
      self.minimum_duration_for_tick_update = 10.seconds

      attr_accessor :task_count

      def control(&block)
        @control = block
      end

      def task_enumerator(*)
        @state = :run
        Enumerator.new do |yielder|
          iteration = 1
          loop do
            yielder.yield(iteration)
            break if @state == :stop
            iteration += 1
          end
        end
      end

      def task_iteration(iteration)
        @state = @control.call(iteration)
      end
    end

    def setup
      CancelledTask.clear
      PausedTask.clear
      SuccessfulTask.clear
      InterruptedTask.clear
      ControlledTask.clear
    end

    test '.available_tasks returns list of tasks that inherit from the Task superclass' do
      expected = [
        'Maintenance::ErrorTask',
        'Maintenance::UpdatePostsTask',
        'MaintenanceTasks::TaskTest::CancelledTask',
        'MaintenanceTasks::TaskTest::ControlledTask',
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

    test '.runs returns the Active Record relation of the runs associated with a Task' do
      run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')

      assert_equal 1, Maintenance::UpdatePostsTask.runs.count
      assert_equal run, Maintenance::UpdatePostsTask.runs.first
    end

    test '.active_run returns the only enqueued, running, or paused run associated with a Task' do
      run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')

      assert_equal run, Maintenance::UpdatePostsTask.active_run

      run.running!
      assert_equal run, Maintenance::UpdatePostsTask.active_run

      run.paused!
      assert_equal run, Maintenance::UpdatePostsTask.active_run

      run.succeeded!
      assert_nil Maintenance::UpdatePostsTask.active_run
    end

    test '.perform_now exits job when Run is paused' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::PausedTask')

      PausedTask.perform_now(run)

      assert_equal ['running', 'paused'], PausedTask.run_status_snapshots
      assert_predicate run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test '.perform_now exits job when Run is cancelled' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::CancelledTask')

      CancelledTask.perform_now(run)

      assert_equal ['running', 'cancelled'], CancelledTask.run_status_snapshots
      assert_predicate run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test 'a Run can be paused before it starts performing' do
      run = Run.create!(
        task_name: 'MaintenanceTasks::TaskTest::SuccessfulTask',
        status: :paused
      )

      SuccessfulTask.perform_now(run)

      assert_equal ['paused', 'paused'], SuccessfulTask.run_status_snapshots
      assert_predicate run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test 'a Run can be cancelled before it starts performing' do
      run = Run.create!(
        task_name: 'MaintenanceTasks::TaskTest::SuccessfulTask',
        status: :cancelled
      )

      SuccessfulTask.perform_now(run)

      expected_statuses = ['cancelled', 'cancelled']
      assert_equal expected_statuses, SuccessfulTask.run_status_snapshots
      assert_predicate run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test 'tick_count is updated after the minimum duration' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::ControlledTask')
      task = ControlledTask.new(run)
      freeze_time
      task.control do |iteration|
        if iteration == 1
          travel 11.second
        else
          assert_equal 1, run.reload.tick_count
          :stop
        end
      end
      task.perform_now
      refute assertions.zero?
    end

    test "tick_count isn't updated under the minimum duration" do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::ControlledTask')
      task = ControlledTask.new(run)
      freeze_time
      task.control do |iteration|
        if iteration == 1
          travel 9.seconds
        else
          assert_equal 0, run.reload.tick_count
          :stop
        end
      end
      task.perform_now
      refute assertions.zero?
    end

    test 'tick_count is updated for multiple ticks after the duration' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::ControlledTask')
      task = ControlledTask.new(run)
      freeze_time
      task.control do |iteration|
        if iteration <= 2
          travel 6.seconds
        else
          assert_equal 2, run.reload.tick_count
          :stop
        end
      end
      task.perform_now
      refute assertions.zero?
    end

    test 'tick_count is updated when the job is interrupted' do
      run = Run.create!(
        task_name: 'MaintenanceTasks::TaskTest::InterruptedTask',
      )
      InterruptedTask.perform_now(run)
      assert_equal 1, run.reload.tick_count
    end

    test '#task_count is nil by default' do
      task = Task.new
      assert_nil task.task_count
    end

    test 'tick_total is updated when the job starts, before iteration' do
      run = Run.create!(task_name: 'MaintenanceTasks::TaskTest::ControlledTask')
      task = ControlledTask.new(run)
      task.task_count = 42
      task.control do
        assert_equal 42, run.reload.tick_total
        :stop
      end
      task.perform_now
      refute assertions.zero?
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

    test 'updates associated on Run to errored if exception is raised' do
      run = Run.create!(task_name: 'Maintenance::ErrorTask')
      Maintenance::ErrorTask.perform_now(run)

      run.reload
      assert_equal 'ArgumentError', run.error_class
      assert_equal 'Something went wrong', run.error_message

      expected = ["app/jobs/maintenance/error_task.rb:9:in `task_iteration'"]
      assert_equal expected, run.backtrace
      assert_predicate run.reload, :errored?
    end

    test 'does not enqueue another job if Run errors' do
      run = Run.create!(task_name: 'Maintenance::ErrorTask')

      assert_no_enqueued_jobs do
        Maintenance::ErrorTask.perform_now(run)
      end
    end
  end
end
