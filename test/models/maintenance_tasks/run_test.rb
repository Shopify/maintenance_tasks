# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test '#enqueue enqueues the Task Job for the current Run' do
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')

      assert_enqueued_with job: MaintenanceTasks.job, args: [run] do
        run.enqueue
        assert_predicate run, :persisted?
      end
    end

    test "invalid if the task doesn't exist" do
      run = Run.new(task_name: 'Maintenance::DoesNotExist')
      refute run.valid?
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

    test '#reload_status reloads status and clears dirty tracking' do
      run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')
      Run.find(run.id).running!

      run.reload_status
      assert_predicate run, :running?
      refute run.changed?
    end

    test '#reload_status does not use query cache' do
      run = Run.create!(task_name: 'Maintenance::UpdatePostsTask')
      query_count = count_uncached_queries do
        ActiveRecord::Base.connection.cache do
          run.reload_status
          run.reload_status
        end
      end
      assert_equal 2, query_count
    end

    test '#stopped? returns true if status is paused or cancelled' do
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')

      (Run.statuses.keys - ['paused', 'cancelled']).each do |status|
        run.status = status
        refute_predicate run, :stopped?
      end

      run.status = :paused
      assert_predicate run, :stopped?

      run.status = :cancelled
      assert_predicate run, :stopped?
    end

    test '#started? returns false if the Run has no started_at timestamp' do
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')
      refute_predicate run, :started?
    end

    test '#started? returns true if the Run has a started_at timestamp' do
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        started_at: Time.now
      )
      assert_predicate run, :started?
    end

    test '#completed? returns true if status is succeeded, errored, or cancelled' do
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')

      (Run::STATUSES - Run::COMPLETED_STATUSES).each do |status|
        run.status = status
        refute_predicate run, :completed?
      end

      Run::COMPLETED_STATUSES.each do |status|
        run.status = status
        assert_predicate run, :completed?
      end
    end

    test '#eta returns nil if the run is completed' do
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :succeeded
      )

      assert_nil run.eta
    end

    test '#eta returns nil if tick_count is 0' do
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running,
        tick_count: 0,
        tick_total: 10
      )

      assert_nil run.eta
    end

    test '#eta returns nil if no tick_total' do
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running,
        tick_count: 1
      )

      assert_nil run.eta
    end

    test '#estimated_completion_time returns estimated completion time based on average time elapsed per tick' do
      started_at = Time.utc(2020, 1, 9, 9, 41, 44)
      travel_to started_at + 9.seconds

      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        started_at: started_at,
        status: :running,
        tick_count: 9,
        tick_total: 10
      )

      expected_completion_time = Time.utc(2020, 1, 9, 9, 41, 54)
      assert_equal expected_completion_time, run.estimated_completion_time
    end

    private

    def count_uncached_queries(&block)
      count = 0

      query_cb = ->(*, payload) { count += 1 unless payload[:cached] }
      ActiveSupport::Notifications.subscribed(query_cb,
        'sql.active_record',
        &block)

      count
    end
  end
end
