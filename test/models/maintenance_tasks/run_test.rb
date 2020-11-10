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
