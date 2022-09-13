# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class RunnerTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @name = "Maintenance::UpdatePostsTask"
      @runner = Runner
      @job = MaintenanceTasks.job.constantize
      @csv = file_fixture("sample.csv")
    end

    test "#run creates and performs a Run for the given Task" do
      assert_difference -> { Run.where(task_name: @name).count }, 1 do
        assert_enqueued_with(job: @job) do
          assert_equal Maintenance::UpdatePostsTask, @runner.run(name: @name)
        end
      end
    end

    test "#run enqueues a new Run for the Task when one already exists" do
      Run.create!(task_name: @name, status: :paused)

      assert_difference -> { Run.where(task_name: @name).count }, 1 do
        assert_enqueued_with(job: @job) do
          assert_equal Maintenance::UpdatePostsTask, @runner.run(name: @name)
        end
      end
    end

    test "#run sets the job_id" do
      assert_enqueued_with(job: @job) do
        assert_equal Maintenance::UpdatePostsTask, @runner.run(name: @name)
      end
      run = Run.last
      assert_not_nil run.job_id
    end

    # Yielding the run is undocumented and not supported in the Runner's API
    test "#run yields the newly created Run" do
      @runner.run(name: @name) { |run| @run = run }
      assert_equal Run.last, @run
    end

    # Yielding the run is undocumented and not supported in the Runner's API
    test "#run always yields the newly created Run" do
      Run.create!(task_name: @name, status: :paused)

      @runner.run(name: @name) { |yielded| @run = yielded }
      assert_equal Run.last, @run
    end

    test "#run raises validation error if no Task for given name" do
      assert_no_difference -> { Run.where(task_name: "Invalid").count } do
        assert_no_enqueued_jobs do
          error = assert_raises(ActiveRecord::RecordInvalid) do
            @runner.run(name: "Invalid")
          end

          assert_equal(
            "Validation failed: Task name is not included in the list",
            error.message,
          )
        end
      end
    end

    test "#run raises enqueuing errors if enqueuing raises" do
      assert_no_enqueued_jobs do
        error = assert_raises(Runner::EnqueuingError) do
          @runner.run(name: "Maintenance::EnqueueErrorTask")
        end

        assert_equal(
          "The job to perform Maintenance::EnqueueErrorTask "\
            "could not be enqueued",
          error.message,
        )
        assert_kind_of RuntimeError, error.cause
        assert_equal "Error enqueuing", error.cause.message
      end
    end

    test "#run raises enqueuing errors if enqueuing is unsuccessful" do
      assert_no_enqueued_jobs do
        error = assert_raises(Runner::EnqueuingError) do
          @runner.run(name: "Maintenance::CancelledEnqueueTask")
        end

        assert_equal(
          "The job to perform Maintenance::CancelledEnqueueTask "\
            "could not be enqueued",
          error.message,
        )
        assert_kind_of RuntimeError, error.cause
        assert_equal(
          "The job to perform Maintenance::CancelledEnqueueTask "\
            "could not be enqueued. "\
            "Enqueuing has been prevented by a callback.",
          error.cause.message,
        )
      end
    end

    test "#run raises ActiveRecord::ValueTooLong error if arguments input is too long" do
      Run.any_instance.expects(:enqueued!).raises(ActiveRecord::ValueTooLong)
      assert_raises(ActiveRecord::ValueTooLong) do
        @runner.run(
          name: "Maintenance::ParamsTask",
          arguments: { post_ids: "123" },
        )
      end
    end

    test "#run attaches CSV file to Run if one is provided" do
      @runner.run(name: "Maintenance::ImportPostsTask", csv_file: csv_io)

      run = Run.last
      assert_predicate run.csv_file, :attached?
      assert_equal File.read(@csv), run.csv_file.download
    end

    test "#run raises if CSV file is provided but Task does not process CSVs" do
      assert_no_difference -> { Run.where(task_name: @name).count } do
        error = assert_raises(ActiveRecord::RecordInvalid) do
          @runner.run(name: @name, csv_file: csv_io)
        end

        assert_equal(
          "Validation failed: Csv file should not be attached to non-CSV Task.",
          error.message,
        )
      end
    end

    test "#run raises if no CSV file is provided and Task processes CSVs" do
      task_name = "Maintenance::ImportPostsTask"
      assert_no_difference -> { Run.where(task_name: task_name).count } do
        assert_no_enqueued_jobs do
          error = assert_raises(ActiveRecord::RecordInvalid) do
            @runner.run(name: task_name, csv_file: nil)
          end

          assert_equal(
            "Validation failed: Csv file must be attached to CSV Task.",
            error.message,
          )
        end
      end
    end

    test "#run overrides the file name" do
      travel_to "2021-08-05T12:05:42Z"
      @runner.run(name: "Maintenance::ImportPostsTask", csv_file: csv_io)

      run = Run.last
      assert_equal "20210805T120542Z_maintenance_import_posts_task.csv",
        run.csv_file.filename.to_s
    end

    private

    def csv_io
      { io: File.open(@csv), filename: "sample.csv", content_type: "text/csv" }
    end
  end
end
