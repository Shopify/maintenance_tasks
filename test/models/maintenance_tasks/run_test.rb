# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunTest < ActiveSupport::TestCase
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

    test '#stopping? returns true if status is pausing or cancelling' do
      run = Run.new(task_name: 'Maintenance::UpdatePostsTask')

      (Run.statuses.keys - ['pausing', 'cancelling']).each do |status|
        run.status = status
        refute_predicate run, :stopping?
      end

      run.status = :pausing
      assert_predicate run, :stopping?

      run.status = :cancelling
      assert_predicate run, :stopping?
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

    test '#estimated_completion_time returns nil if the run is completed' do
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :succeeded
      )

      assert_nil run.estimated_completion_time
    end

    test '#estimated_completion_time returns nil if tick_count is 0' do
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running,
        tick_count: 0,
        tick_total: 10
      )

      assert_nil run.estimated_completion_time
    end

    test '#estimated_completion_time returns nil if no tick_total' do
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :running,
        tick_count: 1
      )

      assert_nil run.estimated_completion_time
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

    test '#cancel transitions the Run to cancelling if not paused' do
      [:enqueued, :running, :pausing, :interrupted].each do |status|
        run = Run.create!(
          task_name: 'Maintenance::UpdatePostsTask',
          status: status,
        )
        run.cancel

        assert_predicate run, :cancelling?
      end
    end

    test '#cancel transitions the Run to cancelled if paused and updates ended_at' do
      freeze_time
      run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        status: :paused,
      )
      run.cancel

      assert_predicate run, :cancelled?
      assert_equal Time.now, run.ended_at
    end

    test "#adjust_time_running sets time_running to the difference between now and Run's started_at" do
      freeze_time
      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        started_at: Time.now
      )

      travel 2.seconds

      run.adjust_time_running
      assert_equal 2, run.time_running
    end

    test '#adjust_time_running adds to existing time_running if Run has last_resumed_at timestamp' do
      freeze_time
      started_at = Time.now
      travel 2.seconds

      run = Run.create!(
        task_name: 'Maintenance::UpdatePostsTask',
        started_at: started_at,
        time_running: 2
      )

      run.update!(status: :running, last_resumed_at: Time.now)

      travel 1.second

      run.adjust_time_running
      assert_equal 3, run.time_running
    end

    test '#estimated_completion_time computes completion time correctly when run is paused' do
      started_at = Time.utc(2020, 1, 9, 9, 41, 44)
      travel_to started_at + 9.seconds

      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        started_at: started_at,
        status: :running,
        tick_count: 9,
        tick_total: 10
      )

      run.assign_attributes(status: :paused, time_running: 9.seconds)

      travel 2.minutes

      expected_completion_time = Time.utc(2020, 1, 9, 9, 43, 54)
      assert_equal expected_completion_time, run.estimated_completion_time
    end

    test '#estimated_completion_time computes completion time correctly when run was paused and resumed' do
      started_at = Time.utc(2020, 1, 9, 9, 41, 44)
      travel_to started_at + 6.seconds

      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        started_at: started_at,
        status: :running,
        tick_count: 6,
        tick_total: 10
      )

      run.assign_attributes(status: :paused, time_running: 6.seconds)

      travel 2.minutes

      run.assign_attributes(status: :running, last_resumed_at: Time.now)

      expected_completion_time = Time.utc(2020, 1, 9, 9, 43, 54)
      assert_equal expected_completion_time, run.estimated_completion_time
    end

    test '#estimated_completion_time computes completion time correctly when run is paused multiple times' do
      started_at = Time.utc(2020, 1, 9, 9, 41, 44)
      travel_to started_at + 6.seconds

      run = Run.new(
        task_name: 'Maintenance::UpdatePostsTask',
        started_at: started_at,
        status: :running,
        tick_count: 6,
        tick_total: 10
      )

      run.assign_attributes(status: :paused, time_running: 6.seconds)

      travel 2.minutes
      run.assign_attributes(status: :running, last_resumed_at: Time.now)

      travel 2.seconds
      run.tick_count = 8

      expected_completion_time = Time.utc(2020, 1, 9, 9, 43, 54)
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
