# frozen_string_literal: true

require "application_system_test_case"

module MaintenanceTasks
  class RunsTest < ApplicationSystemTestCase
    test "run a Task" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsTask")
      click_on "Run"

      assert_title "Maintenance::UpdatePostsTask"
      assert_text "Enqueued"
      assert_text "Waiting to start."
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
      fill_in("_task_arguments_post_ids", with: post_id.to_s)

      perform_enqueued_jobs do
        click_on "Run"
      end

      assert_title "Maintenance::ParamsTask"
      assert_text "Succeeded"
      assert_text "Processed 1 out of 1 item (100%)."
      assert_text "Arguments"
      assert_table do |table|
        table.assert_text("post_ids")
        table.assert_text(post_id.to_s)
      end
    end

    test "errors for Task with invalid arguments shown" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")
      fill_in("_task_arguments_post_ids", with: "xyz")
      click_on "Run"

      assert_text "Validation failed: Arguments are invalid: :post_ids is invalid"
    end

    test "download the CSV attached to a run for a CSV Task" do
      visit(maintenance_tasks_path)

      click_on("Maintenance::ImportPostsTask")
      attach_file("csv_file", "test/fixtures/files/sample.csv")
      click_on("Run")

      perform_enqueued_jobs
      page.refresh

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
      click_on "Pause"

      assert_text "Pausing"
      assert_text "Pausing…"
    end

    test "resume a Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      click_on "Pause"
      perform_enqueued_jobs
      page.refresh
      click_on "Resume"

      assert_text "Enqueued"
      assert_text "Waiting to start."
    end

    test "cancel a Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      click_on "Cancel"

      assert_text "Cancelling"
      assert_text "Cancelling…"
    end

    test "cancel a pausing Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      click_on "Pause"
      assert_text "Pausing"

      click_on "Cancel"
      assert_text "Cancelling…"
    end

    test "cancel a stuck Run" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")
      click_on "Run"
      click_on "Cancel"

      assert_text "Cancelling…"
      refute_button "Cancel"

      travel Run::STUCK_TASK_TIMEOUT

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

      perform_enqueued_jobs do
        click_on "Run"
      end

      assert_text "Errored"
      assert_text "Ran for less than 5 seconds until an error happened less than a minute ago."
      assert_text "ArgumentError"
      assert_text "Something went wrong"
      assert_text "app/tasks/maintenance/error_task.rb:10:in `process'"
    end

    test "errors for double enqueue are shown" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsInBatchesTask")

      click_on "Run"
      click_on "Pause"

      perform_enqueued_jobs

      page.refresh

      url = page.current_url
      using_session(:other_tab) do
        visit url
        click_on "Resume"
      end

      click_on "Resume"

      assert_text "Validation failed: Status Cannot transition run from status enqueued to enqueued"
    end

    test "errors when enqueuing are shown" do
      visit maintenance_tasks_path

      click_on "Maintenance::EnqueueErrorTask"
      click_on "Run"
      assert_text "The job to perform Maintenance::EnqueueErrorTask could not be enqueued"
      assert_text "Error enqueuing"

      visit maintenance_tasks_path
      click_on "Maintenance::CancelledEnqueueTask"
      click_on "Run"
      assert_text "The job to perform Maintenance::CancelledEnqueueTask could not be enqueued"
      assert_text "The job to perform Maintenance::CancelledEnqueueTask "\
        "could not be enqueued. Enqueuing has been prevented by a callback."
    end

    test "errors for invalid pause or cancel due to stale UI are shown" do
      visit maintenance_tasks_path
      click_on("Maintenance::UpdatePostsInBatchesTask")

      url = page.current_url
      click_on "Run"

      using_session(:other_tab) do
        visit url
        click_on "Cancel"
      end

      click_on "Pause"

      assert_text "Validation failed: Status Cannot transition run from status cancelling to pausing"
    end
  end
end
