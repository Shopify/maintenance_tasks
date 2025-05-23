# frozen_string_literal: true

require "application_system_test_case"

module MaintenanceTasks
  class RunsTest < ApplicationSystemTestCase
    test "run a Task" do
      visit maintenance_tasks_path

      assert_difference("Run.count") do
        click_on("Maintenance::UpdatePostsTask")
        click_on "Run"

        assert_title "Maintenance::UpdatePostsTask"
        assert_text "Enqueued"
        assert_text "Waiting to start."
      end
      run = Run.last
      assert_nil run.metadata
      assert_equal "Maintenance::UpdatePostsTask", run.task_name
      assert_equal "enqueued", run.status
    end

    test "run a Task and log the provided metadata" do
      MaintenanceTasks.metadata = -> { { user_email: "michael.elfassy@shopify.com" } }
      visit(maintenance_tasks_path)

      assert_difference("Run.count") do
        click_on("Maintenance::UpdatePostsTask")
        click_on("Run")

        assert_title("Maintenance::UpdatePostsTask")
        assert_text("Enqueued")
        assert_text("Waiting to start.")
        assert_text("Metadata")
        assert_text("user_email")
        assert_text("michael.elfassy@shopify.com")
      end
      run = Run.last
      assert_equal("michael.elfassy@shopify.com", run.metadata["user_email"])
      assert_equal("Maintenance::UpdatePostsTask", run.task_name)
      assert_equal("enqueued", run.status)
    ensure
      MaintenanceTasks.metadata = nil
    end

    test "metadata can be non-hash" do
      MaintenanceTasks.metadata = -> { "hello metadata" }
      visit(maintenance_tasks_path)

      assert_difference("Run.count") do
        click_on("Maintenance::UpdatePostsTask")
        click_on("Run")
        assert_text("Enqueued")

        assert_text("hello metadata")
      end
    ensure
      MaintenanceTasks.metadata = nil
    end

    test "run a CSV Task" do
      visit maintenance_tasks_path

      click_on("Maintenance::ImportPostsTask")
      attach_file("csv_file", "test/fixtures/files/sample.csv")
      click_on "Run"

      assert_title "Maintenance::ImportPostsTask"
      assert_text "Enqueued"
      assert_text "Waiting to start."
    end

    test "run a Task that accepts parameters" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")
      post_id = Post.first.id
      fill_in("task[post_ids]", with: post_id.to_s)

      click_on "Run"
      assert_text "Enqueued"

      perform_enqueued_jobs
      refresh

      assert_title "Maintenance::ParamsTask"
      assert_text "Succeeded"
      assert_text "Processed 1 out of 1 item (100%)."
      assert_text "Arguments"
      assert_text("post_ids")
      assert_text(post_id.to_s)
    end

    test "parameters are preserved from the refresh" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")
      post_id = Post.first.id
      fill_in("task[post_ids]", with: post_id.to_s)

      click_on "Run"
      assert_text "Enqueued"
      fill_in("task[post_ids]", with: 42)

      perform_enqueued_jobs
      # no refresh to test the fields are preserved

      assert_text "Succeeded", wait: 3 # auto-refreshes every 3 seconds
      assert_text(post_id.to_s)
    end

    test "run a Task that accepts masked parameters" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")
      post_id = Post.first.id
      assert_title "Maintenance::ParamsTask"
      fill_in("task[post_ids]", with: post_id.to_s)

      click_on "Run"
      assert_text "Enqueued"

      perform_enqueued_jobs
      refresh

      assert_title "Maintenance::ParamsTask"
      assert_text "Succeeded"
      assert_text "Processed 1 out of 1 item (100%)."
      assert_text "Arguments"
      assert_text("sensitive_content")
      assert_text("[FILTERED]")
      assert has_field?("task[sensitive_content]", with: "default sensitive content")
    end

    test "errors for Task with invalid arguments shown" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")
      fill_in("task[post_ids]", with: "xyz")
      fill_in("task[content]", with: "super content")
      click_on "Run"

      assert_text "Validation failed: Arguments are invalid: :post_ids is invalid"
      assert_field "task[content]", with: "super content"
    end

    test "download the CSV attached to a run for a CSV Task" do
      visit(maintenance_tasks_path)

      click_on("Maintenance::ImportPostsTask")
      attach_file("csv_file", "test/fixtures/files/sample.csv")
      click_on("Run")
      assert_text "Enqueued"

      perform_enqueued_jobs
      refresh

      click_on("Download CSV")

      downloaded_csv = "test/dummy/tmp/downloads/20200109T094144Z_maintenance_import_posts_task.csv"

      Timeout.timeout(1) do
        sleep(0.1) until File.exist?(downloaded_csv)
      end
      assert(File.exist?(downloaded_csv))
    end

    test "pause a Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsTask")
      click_on "Run"
      assert_text "Enqueued"

      click_on "Pause"
      assert_text "Pausing"
      assert_text "Pausing…"
    end

    test "resume a Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      assert_text "Enqueued"

      click_on "Pause"
      assert_text "Pausing" # ensure page loaded

      perform_enqueued_jobs
      refresh
      click_on "Resume"

      assert_text "Enqueued"
      assert_text "Waiting to start."
    end

    test "cancel a Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      assert_text "Enqueued"
      click_on "Cancel"

      assert_text "Cancelling"
      assert_text "Cancelling…"
    end

    test "cancel a pausing Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      assert_text "Enqueued"
      click_on "Pause"
      assert_text "Pausing"

      click_on "Cancel"
      assert_text "Cancelling…"
    end

    test "cancel a stuck Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      assert_text "Enqueued"

      click_on "Cancel"
      assert_text "Cancelling…"

      refute_button "Cancel"

      travel MaintenanceTasks.stuck_task_duration

      refresh
      click_on "Cancel"
    end

    test "cancel a deleted task" do
      visit maintenance_tasks_path + "/tasks/Maintenance::PausedDeletedTask"

      click_on "Cancel"

      assert_text "Cancelled"
    end

    test "run a Task that errors" do
      visit maintenance_tasks_path

      click_on("Maintenance::ErrorTask")

      click_on "Run"
      assert_text "Enqueued"

      perform_enqueued_jobs
      refresh

      assert_text "Errored"
      assert_text "Ran for less than 5 seconds until an error happened less than a minute ago."
      assert_text "ArgumentError"
      assert_text "Something went wrong"
      assert_text %r{app/tasks/maintenance/error_task\.rb:10:in ('Maintenance::ErrorTask#|`)process'}
    end

    test "resume an errored Task" do
      visit maintenance_tasks_path

      click_on("Maintenance::ErrorTask")

      click_on "Run"
      assert_text "Enqueued"

      perform_enqueued_jobs
      refresh

      assert_text "Errored"

      click_on "Resume"

      assert_text "Enqueued"
      assert_text "Waiting to start."
    end

    test "errors for double enqueue are shown" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")

      click_on "Run"
      assert_text "Enqueued"

      click_on "Pause"
      assert_text "Pausing"

      perform_enqueued_jobs

      refresh

      url = page.current_url
      using_session(:other_tab) do
        visit url
        click_on "Resume"
      end

      click_on "Resume"

      assert_text "Validation failed: Status Cannot transition run from status enqueued to enqueued"
    end

    test "enqueuing errors are shown" do
      visit maintenance_tasks_path

      click_on "Maintenance::EnqueueErrorTask"
      click_on "Run"
      assert_text "The job to perform Maintenance::EnqueueErrorTask could not be enqueued"
      assert_text "Error enqueuing"
    end

    test "enqueuing cancellations are shown" do
      visit maintenance_tasks_path
      click_on "Maintenance::CancelledEnqueueTask"
      click_on "Run"
      find(".notification") do
        assert_text "The job to perform Maintenance::CancelledEnqueueTask could not be enqueued"
      end
      assert_text "The job to perform Maintenance::CancelledEnqueueTask " \
        "could not be enqueued. Enqueuing has been prevented by a callback."
    end

    test "errors for invalid pause or cancel due to stale UI are shown" do
      visit maintenance_tasks_path
      click_on("Maintenance::UpdatePostsInBatchesTask")

      url = page.current_url
      click_on "Run"
      assert_text "Enqueued"

      using_session(:other_tab) do
        visit url
        click_on "Cancel"
      end

      click_on "Pause"

      assert_text "Validation failed: Status Cannot transition run from status cancelling to pausing"
    end
  end
end
