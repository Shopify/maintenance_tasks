# frozen_string_literal: true

require "test_helper"
require "job-iteration"

module MaintenanceTasks
  class TaskJobTest < ActiveJob::TestCase
    setup do
      @run = Run.create!(task_name: "Maintenance::TestTask")
    end

    test ".perform_now exits job when Run is paused, and updates Run status from pausing to paused" do
      Maintenance::TestTask.any_instance.expects(:process).once.with do
        @run.pausing!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test ".perform_now exits job when Run is cancelled, and updates Run status from cancelling to cancelled" do
      Maintenance::TestTask.any_instance.expects(:process).once.with do
        @run.cancelling!
      end

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test ".perform doesn't run a cancelled job" do
      freeze_time
      TaskJob.perform_later(@run)
      @run.cancel
      travel Run::STUCK_TASK_TIMEOUT
      @run.cancel # force cancel the Run
      assert_predicate @run, :cancelled?
      Maintenance::TestTask.any_instance.expects(:process).never

      assert_nothing_raised do
        perform_enqueued_jobs
      end
    end

    test ".perform_now persists ended_at when the Run is cancelled" do
      freeze_time
      Maintenance::TestTask.any_instance.expects(:process).once.with do
        @run.cancelling!
      end

      TaskJob.perform_now(@run)

      assert_equal Time.now, @run.reload.ended_at
    end

    test ".perform_now skips iterations when Run is paused" do
      @run.pausing!

      Maintenance::TestTask.any_instance.expects(:process).never

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :paused?
      assert_no_enqueued_jobs
    end

    test ".perform_now avoids iterating when Run is cancelled" do
      @run.cancelling!

      Maintenance::TestTask.any_instance.expects(:process).never

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :cancelled?
      assert_no_enqueued_jobs
    end

    test ".perform_now avoids iterating and cancels Run when a race occurs between starting and cancelling" do
      CustomTaskJob.race_condition_hook = -> do
        Run.find(@run.id).update(status: :cancelling)
      end

      Maintenance::TestTask.any_instance.expects(:process).never

      CustomTaskJob.perform_now(@run)

      assert_predicate(@run.reload, :cancelled?)
      assert_no_enqueued_jobs
    ensure
      CustomTaskJob.race_condition_hook = nil
    end

    test ".perform_now updates tick_count" do
      Maintenance::TestTask.any_instance.expects(:process).twice

      TaskJob.perform_now(@run)

      assert_equal 2, @run.reload.tick_count
    end

    test ".perform_now updates tick_count when job is interrupted" do
      JobIteration.stubs(interruption_adapter: -> { true })
      Maintenance::TestTask.any_instance.expects(:process).once

      TaskJob.perform_now(@run)

      assert_equal 1, @run.reload.tick_count
    end

    test ".perform_now persists started_at when the job starts" do
      freeze_time
      Maintenance::TestTask.any_instance.expects(:process).once.with do
        @run.cancelling!
      end

      TaskJob.perform_now(@run)

      assert_equal Time.now, @run.reload.started_at
    end

    test ".perform_now updates Run to running when job starts performing" do
      Maintenance::TestTask.any_instance.expects(:process).twice.with do
        assert_predicate @run.reload, :running?
      end

      TaskJob.new(@run).perform_now
    end

    test ".perform_now updates Run to succeeded and persists ended_at when job finishes successfully" do
      freeze_time
      Maintenance::TestTask.any_instance.expects(:process).twice
      TaskJob.perform_now(@run)

      assert_equal Time.now, @run.reload.ended_at
      assert_predicate @run, :succeeded?
    end

    test ".perform_now updates Run to interrupted when job is interrupted" do
      JobIteration.stubs(interruption_adapter: -> { true })
      Maintenance::TestTask.any_instance.expects(:process).once

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :interrupted?
    end

    test ".perform_now re-enqueues the job when interrupted" do
      JobIteration.stubs(interruption_adapter: -> { true })
      Maintenance::TestTask.any_instance.expects(:process).once

      assert_enqueued_with(job: TaskJob) { TaskJob.perform_now(@run) }
    end

    test ".perform_now updates Run to errored and persists ended_at when exception is raised" do
      freeze_time
      run = Run.create!(task_name: "Maintenance::ErrorTask")

      run.expects(:persist_error).with do |exception|
        assert_kind_of ArgumentError, exception
        assert_equal "Something went wrong", exception.message
        expected = "app/tasks/maintenance/error_task.rb:10:in `process'"
        assert_match expected, exception.backtrace.first
      end

      TaskJob.perform_now(run)
    end

    test ".perform_now handles when the Task cannot be found" do
      run = Run.new(task_name: "Maintenance::DeletedTask")
      run.save(validate: false)

      TaskJob.perform_now(run)

      assert_equal "MaintenanceTasks::Task::NotFoundError", run.error_class
      assert run.error_message
        .start_with?("Task Maintenance::DeletedTask not found.")
    end

    test ".perform_now handles when the Task cannot be found when resuming after interruption" do
      run = Run.new(task_name: "Maintenance::DeletedTask")
      run.save(validate: false)
      run.running! # the Task existed when the run started
      run.interrupted! # but not after interruption

      TaskJob.perform_now(run)

      assert_equal "MaintenanceTasks::Task::NotFoundError", run.error_class
      assert run.error_message
        .start_with?("Task Maintenance::DeletedTask not found.")
    end

    test ".perform_now delays reenqueuing the job after interruption until all callbacks are finished" do
      JobIteration.stubs(interruption_adapter: -> { true })

      AnotherTaskJob = Class.new(TaskJob) do
        after_perform { self.class.times_interrupted = times_interrupted }

        class << self
          attr_accessor :times_interrupted
        end
      end
      AnotherTaskJob.perform_now(@run)

      # The job should not yet have been reenqueued, so times_interrupted should
      # be 0
      assert_equal 0, AnotherTaskJob.times_interrupted
      assert_enqueued_jobs 1
    end

    test ".perform_now does not enqueue another job if Run errors" do
      run = Run.create!(task_name: "Maintenance::ErrorTask")

      assert_no_enqueued_jobs { TaskJob.perform_now(run) }
    end

    test ".perform_now updates tick_count when job is errored" do
      Maintenance::TestTask.any_instance.expects(:process).twice
        .returns(nil)
        .raises(ArgumentError)

      TaskJob.perform_now(@run)

      assert_equal 1, @run.reload.tick_count
    end

    test ".perform_now persists cursor when job shuts down" do
      Maintenance::TestTask.any_instance.expects(:process).once.with do
        @run.pausing!
      end

      TaskJob.perform_now(@run)

      assert_equal 0, @run.reload.cursor
    end

    test ".perform_now starts job from cursor position when job resumes" do
      @run.update!(cursor: 0)

      Maintenance::TestTask.any_instance.expects(:process).once.with(2)

      TaskJob.perform_now(@run)
    end

    test ".perform_now accepts Active Record Relations as collection" do
      Maintenance::TestTask.any_instance.stubs(collection: Post.all)
      Maintenance::TestTask.any_instance.expects(:process).times(Post.count)

      TaskJob.perform_now(@run)

      assert_predicate @run.reload, :succeeded?
    end

    test ".perform_now accepts CSVs as collection" do
      Maintenance::ImportPostsTask.any_instance.expects(:process).times(5)

      run = Run.new(task_name: "Maintenance::ImportPostsTask")
      run.csv_file.attach(
        { io: File.open(file_fixture("sample.csv")), filename: "sample.csv" },
      )
      run.save
      TaskJob.perform_now(run)

      assert_predicate run.reload, :succeeded?
    end

    test ".perform_now can run a Task that uses no collection" do
      Maintenance::NoCollectionTask.any_instance.expects(:process).once

      run = Run.new(task_name: "Maintenance::NoCollectionTask")

      TaskJob.perform_now(run)

      assert_predicate run.reload, :succeeded?
    end

    test ".perform_now accepts a CSV collection to be performed in batches" do
      Maintenance::BatchImportPostsTask.any_instance.expects(:process).times(3)

      run = Run.new(task_name: "Maintenance::BatchImportPostsTask")
      run.csv_file.attach(
        { io: File.open(file_fixture("sample.csv")), filename: "sample.csv" },
      )
      run.save
      TaskJob.perform_now(run)
    end

    test ".perform_now sets the Run as errored when the Task collection is invalid" do
      freeze_time
      Maintenance::TestTask.any_instance.stubs(collection: "not a collection")

      TaskJob.perform_now(@run)
      @run.reload

      assert_predicate @run, :errored?
      assert_equal "ArgumentError", @run.error_class
      assert_empty @run.backtrace
      expected_message = <<~MSG.squish
        Maintenance::TestTask#collection must be either an
        Active Record Relation, ActiveRecord::Batches::BatchEnumerator,
        Array, or CSV.
      MSG
      assert @run.error_message.start_with?(expected_message)
      assert_equal Time.now, @run.started_at
    end

    test ".perform_now sets the Run as errored when the Task collection is not defined" do
      collection_method = Maintenance::TestTask.instance_method(:collection)
      Maintenance::TestTask.remove_method(:collection)
      TaskJob.perform_now(@run)
      @run.reload
      assert_predicate(@run, :errored?)
    ensure
      Maintenance::TestTask.define_method(:collection, collection_method)
    end

    test ".perform_now sets the Run as errored when the Task process is not defined" do
      collection_method = Maintenance::TestTask.instance_method(:process)
      Maintenance::TestTask.remove_method(:process)
      TaskJob.perform_now(@run)
      @run.reload
      assert_predicate(@run, :errored?)
    ensure
      Maintenance::TestTask.define_method(:process, collection_method)
    end

    test ".retry_on raises NotImplementedError" do
      assert_raises NotImplementedError do
        Class.new(TaskJob) { retry_on StandardError }
      end
    end

    test ".perform_now calls the error handler when there was an Error" do
      error_handler_before = MaintenanceTasks.error_handler
      handled_error = nil
      handled_task_context = nil
      handled_errored_element = nil

      MaintenanceTasks.error_handler = ->(error, task_context, errored_el) do
        handled_error = error
        handled_task_context = task_context
        handled_errored_element = errored_el
      end

      run = Run.create!(task_name: "Maintenance::ErrorTask")

      TaskJob.perform_now(run)

      assert_equal(ArgumentError, handled_error.class)
      assert_equal("Maintenance::ErrorTask", handled_task_context[:task_name])
      assert_equal(2, handled_errored_element)
    ensure
      MaintenanceTasks.error_handler = error_handler_before
    end

    test ".perform_now still persists the error properly if the error handler raises" do
      error_handler_before = MaintenanceTasks.error_handler
      MaintenanceTasks.error_handler = ->(error, _task_context, _errored_el) do
        raise error
      end
      run = Run.create!(task_name: "Maintenance::ErrorTask")

      assert_raises { TaskJob.perform_now(run) }
      run.reload

      assert_predicate(run, :errored?)
      assert_equal(1, run.tick_count)
    ensure
      MaintenanceTasks.error_handler = error_handler_before
    end

    test ".perform_now handles case where run is not set and calls error handler" do
      error_handler_before = MaintenanceTasks.error_handler
      handled_error = nil
      handled_task_context = nil
      MaintenanceTasks.error_handler = ->(error, task_context, _errored_el) do
        handled_error = error
        handled_task_context = task_context
      end

      RaisingTaskJob = Class.new(TaskJob) do
        before_perform(prepend: true) { raise "Uh oh!" }
      end

      RaisingTaskJob.perform_now(@run)

      assert_equal("Uh oh!", handled_error.message)
      assert_empty(handled_task_context)
    ensure
      MaintenanceTasks.error_handler = error_handler_before
    end

    test ".perform_now throttles when running Task that uses throttle_on" do
      Maintenance::UpdatePostsThrottledTask.throttle = true
      Maintenance::UpdatePostsThrottledTask.throttle_proc = false
      run = Run.create!(task_name: "Maintenance::UpdatePostsThrottledTask")
      TaskJob.perform_now(run)

      assert_predicate run.reload, :interrupted?

      Maintenance::UpdatePostsThrottledTask.throttle = false
      Maintenance::UpdatePostsThrottledTask
        .any_instance
        .expects(:process)
        .times(Post.count)

      perform_enqueued_jobs

      assert_predicate run.reload, :succeeded?
    end

    test ".perform_now throttles when running Task that uses throttle_on with a proc" do
      Maintenance::UpdatePostsThrottledTask.throttle_proc = true
      Maintenance::UpdatePostsThrottledTask.throttle = false

      run = Run.create!(task_name: "Maintenance::UpdatePostsThrottledTask")
      TaskJob.perform_now(run)

      assert_predicate run.reload, :interrupted?

      Maintenance::UpdatePostsThrottledTask.throttle_proc = false
      Maintenance::UpdatePostsThrottledTask
        .any_instance
        .expects(:process)
        .times(Post.count)

      perform_enqueued_jobs

      assert_predicate run.reload, :succeeded?
    end

    test ".perform_now with a throttle doesn't enqueue a job if run is stopping" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsThrottledTask")
      Maintenance::UpdatePostsThrottledTask.any_instance
        .expects(:process).once.with do
        run.cancelling!
        Maintenance::UpdatePostsThrottledTask.throttle = true
      end

      TaskJob.perform_now(run)

      assert_predicate(run.reload, :cancelled?)
      assert_empty(enqueued_jobs)
    ensure
      Maintenance::UpdatePostsThrottledTask.throttle = false
    end

    test ".perform_now makes arguments supplied for Task parameters available" do
      post = Post.last
      Maintenance::ParamsTask.any_instance.expects(:process).once.with(post)

      run = Run.create!(
        task_name: "Maintenance::ParamsTask",
        arguments: { post_ids: post.id.to_s },
      )
      TaskJob.perform_now(run)

      assert_predicate run.reload, :succeeded?
    end

    test ".perform_now handles batch relation tasks" do
      5.times do |i|
        Post.create!(title: "Another Post ##{i}", content: "Content ##{i}")
      end
      # We expect 2 batches (7 posts => 5 + 2)
      Maintenance::UpdatePostsInBatchesTask.any_instance.expects(:process).twice

      run = Run.create!(task_name: "Maintenance::UpdatePostsInBatchesTask")
      TaskJob.perform_now(run)

      run.reload
      assert_equal 2, run.tick_total
      assert_equal 2, run.tick_count
    end

    test ".perform_now raises if +start+ or +finish+ options are used on batch enumerator" do
      batch_enumerator = Post.in_batches(of: 5, start: 1, finish: 10)

      Maintenance::UpdatePostsInBatchesTask.any_instance
        .expects(:collection).returns(batch_enumerator)

      run = Run.create!(task_name: "Maintenance::UpdatePostsInBatchesTask")
      TaskJob.perform_now(run)

      assert_predicate run.reload, :errored?
      assert_equal "ArgumentError", run.error_class
      assert_empty run.backtrace
      expected_message = <<~MSG.squish
        Maintenance::UpdatePostsInBatchesTask#collection cannot support a batch
        enumerator with the "start" or "finish" options.
      MSG
      assert_equal expected_message, run.error_message
    end

    test ".perform_now cancels run when race occurs between interrupting and cancelling run" do
      JobIteration.stubs(interruption_adapter: -> { true })

      # Simulate cancel happening after we've already checked @run.cancelling?
      @run.expects(:cancelling?).twice.with do
        Run.find(@run.id).cancel
      end.returns(false).then.returns(true)

      TaskJob.perform_now(@run)

      assert_predicate(@run.reload, :cancelled?)
    end

    test ".perform_now pauses run when race occurs between interrupting and pausing run" do
      JobIteration.stubs(interruption_adapter: -> { true })

      # Simulate pause happening after we've already checked @run.pausing?
      @run.expects(:pausing?).twice.with do
        Run.find(@run.id).pausing!
      end.returns(false).then.returns(true)

      TaskJob.perform_now(@run)

      assert_predicate(@run.reload, :paused?)
    end

    test ".perform_now marks run as succeeded when run is cancelled before success persists" do
      CustomTaskJob.race_condition_after_hook = -> do
        Run.find(@run.id).cancel
      end

      Maintenance::TestTask.any_instance.expects(:process).twice

      CustomTaskJob.perform_now(@run)

      assert_predicate(@run.reload, :succeeded?)
    ensure
      CustomTaskJob.race_condition_after_hook = nil
    end

    test ".perform_now marks run as succeeded when run is paused before success persists" do
      CustomTaskJob.race_condition_after_hook = -> do
        Run.find(@run.id).pausing!
      end

      Maintenance::TestTask.any_instance.expects(:process).twice

      CustomTaskJob.perform_now(@run)

      assert_predicate(@run.reload, :succeeded?)
    ensure
      CustomTaskJob.race_condition_after_hook = nil
    end

    test ".perform_now raises validation error if run is cancelled right after being saved as succeeded" do
      CustomTaskJob.race_condition_prepended_after_hook = -> do
        assert_raises(ActiveRecord::RecordInvalid) do
          Run.find(@run.id).cancel
        end
      end

      Maintenance::TestTask.any_instance.expects(:process).twice

      CustomTaskJob.perform_now(@run)

      assert_predicate(@run.reload, :succeeded?)
    ensure
      CustomTaskJob.race_condition_prepended_after_hook = nil
    end

    test ".perform_now marks raises validation error if run is paused right after being saved as succeeded" do
      CustomTaskJob.race_condition_prepended_after_hook = -> do
        assert_raises(ActiveRecord::RecordInvalid) do
          Run.find(@run.id).pausing!
        end
      end

      Maintenance::TestTask.any_instance.expects(:process).twice

      CustomTaskJob.perform_now(@run)

      assert_predicate(@run.reload, :succeeded?)
    ensure
      CustomTaskJob.race_condition_prepended_after_hook = nil
    end

    test ".perform_now bubbles up callback errors" do
      Maintenance::CallbackTestTask
        .any_instance
        .expects(:after_start_callback)
        .raises("Callback error!")

      Maintenance::CallbackTestTask.any_instance.expects(:process).never

      run = Run.create!(task_name: "Maintenance::CallbackTestTask")
      run.expects(:persist_error).with do |exception|
        assert_equal "Callback error!", exception.message
      end

      TaskJob.perform_now(run)
    end

    test "Active Record Relation tasks have their count calculated implicitly" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")

      Maintenance::UpdatePostsTask.any_instance.expects(:process).once.with do
        run.cancelling!
      end

      TaskJob.perform_now(run)

      assert_equal 2, run.reload.tick_total
    end

    test "array-based tasks have their count calculated implicitly" do
      Maintenance::TestTask.any_instance.expects(:process).once.with do
        @run.cancelling!
      end

      TaskJob.perform_now(@run)

      assert_equal 2, @run.reload.tick_total
    end
  end
end
