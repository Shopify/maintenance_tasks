# frozen_string_literal: true
require "test_helper"

module MaintenanceTasks
  class RunTest < ActiveSupport::TestCase
    test "invalid if the task doesn't exist" do
      run = Run.new(task_name: "Maintenance::DoesNotExist")
      refute_predicate run, :valid?
    end

    test "invalid if associated with CSV Task and no attachment" do
      run = Run.new(task_name: "Maintenance::ImportPostsTask")
      refute_predicate run, :valid?
    end

    test "invalid if unassociated with CSV Task and attachment" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")
      csv = Rack::Test::UploadedFile.new(file_fixture("sample.csv"), "text/csv")
      run.csv_file.attach(csv)
      refute_predicate run, :valid?
    end

    test "invalid if associated Task has parameters and they are invalid" do
      run = Run.new(
        task_name: "Maintenance::ParamsTask",
        arguments: { post_ids: "xyz" }
      )
      refute_predicate run, :valid?
    end

    test "invalid if arguments used do not match parameters on Task" do
      run = Run.new(
        task_name: "Maintenance::ParamsTask",
        arguments: { post_ids: "1,2,3", bad_argument: "1,2,3" }
      )
      refute_predicate run, :valid?
      assert_equal run.errors.full_messages.first,
        "Unknown parameters: bad_argument"
    end

    test "invalid if arguments are supplied but Task does not support parameters" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        arguments: { post_ids: "1,2,3" }
      )
      refute_predicate run, :valid?
      assert_equal run.errors.full_messages.first,
        "Unknown parameters: post_ids"
    end

    test "#persist_progress persists increments to tick count and time_running" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        tick_count: 40,
        time_running: 10.2,
      )
      run.tick_count = 21
      run.persist_progress(2, 2)

      assert_equal 21, run.tick_count # record is not used or updated
      assert_equal 42, run.reload.tick_count
      assert_equal 12.2, run.time_running
    end

    test "#persist_error updates Run to errored, sets ended_at, and sets started_at if not yet set" do
      freeze_time
      run = Run.create!(task_name: "Maintenance::ErrorTask")

      error = ArgumentError.new("Something went wrong")
      error.set_backtrace(["lib/foo.rb:42:in `bar'"])
      run.persist_error(error)

      assert_predicate run, :errored?
      assert_equal "ArgumentError", run.error_class
      assert_equal "Something went wrong", run.error_message
      assert_equal ["lib/foo.rb:42:in `bar'"], run.backtrace
      assert_equal Time.now, run.started_at
      assert_equal Time.now, run.ended_at
    end

    test "#reload_status reloads status and clears dirty tracking" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      Run.find(run.id).running!

      run.reload_status
      assert_predicate run, :running?
      refute run.changed?
    end

    test "#reload_status does not use query cache" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      query_count = count_uncached_queries do
        ActiveRecord::Base.connection.cache do
          run.reload_status
          run.reload_status
        end
      end
      assert_equal 2, query_count
    end

    test "#stopping? returns true if status is pausing or cancelling" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")

      (Run.statuses.keys - ["pausing", "cancelling"]).each do |status|
        run.status = status
        refute_predicate run, :stopping?
      end

      run.status = :pausing
      assert_predicate run, :stopping?

      run.status = :cancelling
      assert_predicate run, :stopping?
    end

    test "#stopped? is true if Run is paused" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")

      run.status = :paused
      assert_predicate run, :stopped?
    end

    test "#stopped? is true if Run is completed" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")

      Run::COMPLETED_STATUSES.each do |status|
        run.status = status
        assert_predicate run, :stopped?
      end
    end

    test "#stopped? is false if Run is not paused nor completed" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")

      Run::STATUSES.excluding(Run::COMPLETED_STATUSES, :paused).each do |status|
        run.status = status
        refute_predicate run, :stopped?
      end
    end

    test "#started? returns false if the Run has no started_at timestamp" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")
      refute_predicate run, :started?
    end

    test "#started? returns true if the Run has a started_at timestamp" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        started_at: Time.now
      )
      assert_predicate run, :started?
    end

    test "#completed? returns true if status is succeeded, errored, or cancelled" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")

      (Run::STATUSES - Run::COMPLETED_STATUSES).each do |status|
        run.status = status
        refute_predicate run, :completed?
      end

      Run::COMPLETED_STATUSES.each do |status|
        run.status = status
        assert_predicate run, :completed?
      end
    end

    test "#active? returns true if status is among Run::ACTIVE_STATUSES" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")

      (Run::STATUSES - Run::ACTIVE_STATUSES).each do |status|
        run.status = status
        refute_predicate run, :active?
      end

      Run::ACTIVE_STATUSES.each do |status|
        run.status = status
        assert_predicate run, :active?
      end
    end

    test "#time_to_completion returns nil if the run is completed" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        status: :succeeded
      )

      assert_nil run.time_to_completion
    end

    test "#time_to_completion returns nil if tick_count is 0" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
        tick_count: 0,
        tick_total: 10
      )

      assert_nil run.time_to_completion
    end

    test "#time_to_completion returns nil if no tick_total" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
        tick_count: 1
      )

      assert_nil run.time_to_completion
    end

    test "#time_to_completion returns estimated duration until completion based on average time elapsed per tick" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
        tick_count: 9,
        tick_total: 10,
        time_running: 9,
      )

      assert_equal 1.second, run.time_to_completion
    end

    test "#cancel transitions the Run to cancelling if not paused" do
      [:enqueued, :running, :pausing, :interrupted].each do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          status: status,
        )
        run.cancel

        assert_predicate run, :cancelling?
      end
    end

    test "#cancel transitions the Run to cancelled if paused and updates ended_at" do
      freeze_time
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :paused,
      )
      run.cancel

      assert_predicate run, :cancelled?
      assert_equal Time.now, run.ended_at
    end

    test "#stuck? returns true if the Run is cancelling and has not been updated in more than 5 minutes" do
      freeze_time
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :cancelling,
      )
      refute_predicate run, :stuck?

      travel Run::STUCK_TASK_TIMEOUT
      assert_predicate run, :stuck?
    end

    test "#stuck? does not return true for other statuses" do
      freeze_time
      Run.statuses.except("cancelling").each_key do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          status: status,
        )
        travel Run::STUCK_TASK_TIMEOUT
        refute_predicate run, :stuck?
      end
    end

    test "#cancel transitions from cancelling to cancelled if it has not been updated in more than 5 minutes" do
      freeze_time
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :cancelling,
      )

      run.cancel
      assert_predicate run, :cancelling?
      assert_nil run.ended_at

      travel Run::STUCK_TASK_TIMEOUT
      run.cancel
      assert_predicate run, :cancelled?
      assert_equal Time.now, run.ended_at
    end

    test "#enqueued! ensures the status is marked as changed" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")
      run.enqueued!
      assert_equal ["enqueued", "enqueued"], run.status_previous_change
    end

    test "#enqueued! prevents already enqueued Run to be enqueued" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")
      run.enqueued!
      assert_raises(ActiveRecord::RecordInvalid) do
        run.enqueued!
      end
    end

    test "#task returns Task instance for Run" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")
      assert_kind_of Maintenance::UpdatePostsTask, run.task
    end

    test "#validate_task_arguments instantiates Task and assigns arguments if Task has parameters" do
      run = Run.new(
        task_name: "Maintenance::ParamsTask",
        arguments: { post_ids: "1,2,3" }
      )
      run.validate_task_arguments

      assert_predicate run, :valid?
      assert_equal "1,2,3", run.task.post_ids
    end

    private

    def count_uncached_queries(&block)
      count = 0

      query_cb = ->(*, payload) do
        count += 1 if !payload[:cached] && payload[:sql] != "SHOW search_path"
      end
      ActiveSupport::Notifications.subscribed(query_cb,
        "sql.active_record",
        &block)

      count
    end
  end
end
