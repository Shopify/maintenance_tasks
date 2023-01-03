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

    test "invalid if content_type is not text/csv" do
      run = Run.new(task_name: "Maintenance::ImportPostsTask")
      tsv = Rack::Test::UploadedFile.new(
        file_fixture("sample.tsv"),
        "text/tab-separated-values",
      )
      run.csv_file.attach(tsv)
      refute_predicate run, :valid?
    end

    test "invalid if associated Task has parameters and they are invalid" do
      run = Run.new(
        task_name: "Maintenance::ParamsTask",
        arguments: { post_ids: "xyz" },
      )
      refute_predicate run, :valid?
    end

    test "invalid if arguments used do not match parameters on Task" do
      run = Run.new(
        task_name: "Maintenance::ParamsTask",
        arguments: { post_ids: "1,2,3", bad_argument: "1,2,3" },
      )
      refute_predicate run, :valid?
      assert_equal run.errors.full_messages.first,
        "Unknown parameters: bad_argument"
    end

    test "invalid if arguments are supplied but Task does not support parameters" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        arguments: { post_ids: "1,2,3" },
      )
      refute_predicate run, :valid?
      assert_equal run.errors.full_messages.first,
        "Unknown parameters: post_ids"
    end

    test "#persist_transition saves the record" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      run.status = :running
      run.persist_transition
      refute_predicate run, :changed?
      assert_equal run.reload, run
    end

    test "#persist_transition calls the interrupt callback" do
      run = Run.create!(
        task_name: "Maintenance::CallbackTestTask",
        status: "running",
      )
      run.status = :interrupted
      run.task.expects(:after_interrupt_callback)
      run.persist_transition
    end

    test "#persist_transition calls the complete callback" do
      run = Run.create!(task_name: "Maintenance::CallbackTestTask", status: "running")
      run.status = :succeeded
      run.task.expects(:after_complete_callback)
      run.persist_transition
    end

    test "#persist_transition calls the cancel callback" do
      run = Run.create!(
        task_name: "Maintenance::CallbackTestTask",
        status: "cancelling",
      )
      run.status = :cancelled
      run.task.expects(:after_cancel_callback)
      run.persist_transition
    end

    test "#persist_transition calls the pause callback" do
      run = Run.create!(task_name: "Maintenance::CallbackTestTask", status: "pausing")
      run.status = :paused
      run.task.expects(:after_pause_callback)
      run.persist_transition
    end

    test "#persist_transition with a race condition moves the run to the proper status and calls the right callback" do
      run = Run.create!(task_name: "Maintenance::CallbackTestTask", status: "running")
      Run.find(run.id).cancelling!

      run.task.expects(:after_interrupt_callback).never
      run.task.expects(:after_cancel_callback)

      run.status = :interrupted
      run.persist_transition
      assert_predicate run.reload, :cancelled?
    end

    test "#persist_transition with a race condition for a successful run moves to the succeeded status and calls the right callback" do
      run = Run.create!(task_name: "Maintenance::CallbackTestTask", status: "running")
      Run.find(run.id).cancelling!

      run.task.expects(:after_interrupt_callback).never
      run.task.expects(:after_complete_callback)

      run.status = :succeeded
      run.persist_transition
      assert_predicate run.reload, :succeeded?
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

    test "#persist_progress increments the lock version in memory" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      run.persist_progress(2, 2)
      refute_predicate run, :changed?
      lock_version = run.lock_version
      assert_equal run.reload.lock_version, lock_version
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

    test "#persist_error runs the error callback" do
      run = Run.create!(task_name: "Maintenance::CallbackTestTask")
      error = ArgumentError.new("Something went wrong")
      error.set_backtrace(["lib/foo.rb:42:in `bar'"])
      run.task.expects(:after_error_callback)
      run.persist_error(error)
    end

    test "#persist_error can handle error callback raising" do
      run = Run.create!(task_name: "Maintenance::CallbackTestTask")
      error = ArgumentError.new("Something went wrong")
      error.set_backtrace(["lib/foo.rb:42:in `bar'"])

      run.task.expects(:after_error_callback).raises("Callback error!")

      assert_nothing_raised do
        run.persist_error(error)
      end
    end

    test "#persist_error does not raise on longer error class names" do
      run = Run.create!(task_name: "Maintenance::ErrorTask")
      error = ArgumentError.new("Something went wrong")
      class_name = "SomeVeryLongErrorClassName #{"." * 20000}"
      error.class.stubs(name: class_name)
      error.set_backtrace(["lib/foo.rb:42:in `bar'"])

      assert_nothing_raised do
        run.persist_error(error)
      end
      limit = MaintenanceTasks::Run.column_for_attribute(:error_message).limit
      assert_equal class_name.first(255), run.error_class if limit
    end

    test "#persist_error does not raise on longer errors messages" do
      run = Run.create!(task_name: "Maintenance::ErrorTask")
      error_name = "SomeVeryLongErrorMessage #{"." * 20000}"
      error = ArgumentError.new(error_name)
      error.set_backtrace(["lib/foo.rb:42:in `bar'"])

      assert_nothing_raised do
        run.persist_error(error)
      end
      limit = MaintenanceTasks::Run.column_for_attribute(:error_class).limit
      assert_equal error_name.first(limit), run.error_message if limit
    end

    test "#reload_status reloads status and lock version, and clears dirty tracking" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      original_lock_version = run.lock_version

      Run.find(run.id).running! # race condition

      run.reload_status
      assert_predicate run, :running?
      assert_equal original_lock_version + 1, run.lock_version
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

    test "#stopping? returns true if status is pausing or cancelling or cancelled" do
      run = Run.new(task_name: "Maintenance::UpdatePostsTask")

      (Run.statuses.keys - ["pausing", "cancelling", "cancelled"])
        .each do |status|
          run.status = status
          refute_predicate run, :stopping?
        end

      run.status = :pausing
      assert_predicate run, :stopping?

      run.status = :cancelling
      assert_predicate run, :stopping?

      run.status = :cancelled
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
        started_at: Time.now,
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
        status: :succeeded,
      )

      assert_nil run.time_to_completion
    end

    test "#time_to_completion returns nil if tick_count is 0" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
        tick_count: 0,
        tick_total: 10,
      )

      assert_nil run.time_to_completion
    end

    test "#time_to_completion returns nil if no tick_total" do
      run = Run.new(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
        tick_count: 1,
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

    test "with optimistic locking enabled, #running sets an enqueued or interrupted run to running" do
      [:enqueued, :interrupted].each do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          status: status,
        )
        run.running

        assert_predicate run, :running?
        refute_predicate run, :changed?
      end
    end

    test "with optimistic locking disabled, #running sets an enqueued or interrupted run to running" do
      Run.expects(:locking_enabled?).returns(false).at_least_once
      [:enqueued, :interrupted].each do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          status: status,
        )
        run.running

        assert_predicate run, :running?
        refute_predicate run, :changed?
      end
    end

    test "with optimistic locking enabled, #running doesn't set a stopping run to running" do
      [:cancelling, :pausing].each do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          status: status,
        )
        refute_predicate run, :running?
      end
    end

    test "with optimistic locking disabled, #running doesn't set a stopping run to running, and performs no queries" do
      Run.expects(:locking_enabled?).returns(false).at_least_once
      [:cancelling, :pausing].each do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          status: status,
        )
        assert_equal 0, count_uncached_queries { run.running }

        refute_predicate run, :running?
      end
    end

    test "with optimistic locking enabled, #running rescues and retries ActiveRecord::StaleObjectError" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      Run.find(run.id).pausing!

      assert_nothing_raised do
        run.running
      end

      assert_predicate run, :pausing?
    end

    test "with optimistic locking disabled, #running doesn't set a stopping run to running and reloads the status" do
      [:cancelling, :pausing].each do |status|
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
        )
        Run.find(run.id).update(status: status) # race condition
        run.running

        assert_equal status.to_s, run.status
      end
    end

    test "#start persists started_at and tick_total to the Run" do
      freeze_time
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      run.start(2)

      assert_equal 2, run.tick_total
      assert_equal Time.now, run.started_at
    end

    test "#start runs the start callback" do
      run = Run.create!(
        task_name: "Maintenance::CallbackTestTask",
        status: :running,
      )
      run.task.expects(:after_start_callback)
      run.start(2)
    end

    test "#job_shutdown sets running run to interrupted" do
      run = Run.new(status: :running)
      run.job_shutdown
      assert_predicate run, :interrupted?
    end

    test "#job_shutdown sets cancelling run to cancelled, and sets ended_at" do
      freeze_time
      now = Time.now
      run = Run.new(status: :cancelling)
      run.job_shutdown

      assert_predicate run, :cancelled?
      assert_equal now, run.ended_at
    end

    test "#job_shutdown sets pausing run to paused" do
      run = Run.new(status: :pausing)
      run.job_shutdown
      assert_predicate run, :paused?
    end

    test "#job_shutdown doesn't change the status of a cancelled run" do
      run = Run.new(status: :cancelled)
      run.job_shutdown
      assert_predicate run, :cancelled?
    end

    test "#complete sets status to succeeded and sets ended_at" do
      freeze_time
      now = Time.now
      run = Run.new(status: :running)
      run.complete

      assert_predicate run, :succeeded?
      assert_equal now, run.ended_at
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

    test "#cancel calls the cancel callback if the job was paused" do
      run = Run.create!(
        task_name: "Maintenance::CallbackTestTask",
        status: "paused",
      )
      run.task.expects(:after_cancel_callback)
      run.cancel
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
        arguments: { post_ids: "1,2,3" },
      )
      run.validate_task_arguments

      assert_predicate run, :valid?
      assert_equal "1,2,3", run.task.post_ids
    end

    test "#enqueued! rescues and retries ActiveRecord::StaleObjectError" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :paused,
      )
      Run.find(run.id).cancelled!

      assert_raises(ActiveRecord::RecordInvalid) do
        run.enqueued!
      end

      assert_predicate run.reload, :cancelled?
    end

    test "#cancel rescues and retries ActiveRecord::StaleObjectError" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      Run.find(run.id).pausing!

      assert_nothing_raised do
        run.cancel
      end

      assert_predicate run, :cancelling?
    end

    test "#pausing! rescues and retries ActiveRecord::StaleObjectError" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      Run.find(run.id).running!

      assert_nothing_raised do
        run.pausing!
      end

      assert_predicate run, :pausing?
    end

    test "#persist_error rescues and retries ActiveRecord::StaleObjectError" do
      run = Run.create!(
        task_name: "Maintenance::ErrorTask",
        status: :running,
      )

      error = ArgumentError.new("Something went wrong")
      error.set_backtrace(["lib/foo.rb:42:in `bar'"])

      Run.find(run.id).pausing!

      assert_nothing_raised do
        run.persist_error(error)
      end

      assert_predicate run, :errored?
    end

    test "#start rescues and retries ActiveRecord::StaleObjectError" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :running,
      )
      Run.find(run.id).cancelling!

      assert_nothing_raised do
        run.start(2)
      end

      assert_predicate run, :cancelling?
    end

    test "ACTIVE_STATUSES and COMPLETED_STATUSES contain all valid statuses" do
      assert Run::STATUSES.sort ==
        (Run::ACTIVE_STATUSES + Run::COMPLETED_STATUSES).sort
    end

    private

    def count_uncached_queries(&block)
      count = 0

      query_cb = ->(*, payload) do
        count += 1 if !payload[:cached] && payload[:sql] != "SHOW search_path"
      end
      ActiveSupport::Notifications.subscribed(query_cb, "sql.active_record", &block)

      count
    end
  end
end
