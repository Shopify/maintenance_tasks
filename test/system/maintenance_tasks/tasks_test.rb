# frozen_string_literal: true

require "application_system_test_case"

module MaintenanceTasks
  class TasksTest < ApplicationSystemTestCase
    test "list all tasks" do
      visit maintenance_tasks_path

      assert_title "Maintenance Tasks"

      assert_link "Maintenance::UpdatePostsTask"
      assert_link "Maintenance::ErrorTask"
    end

    test "lists tasks by category" do
      visit maintenance_tasks_path

      expected = [
        "Active Tasks",
        "Maintenance::NoCollectionTask\nEnqueued",
        "Maintenance::NoCollectionTask\nPaused",
        "Maintenance::UpdatePostsTask\nPaused",
        "New Tasks",
        "Maintenance::BatchImportPostsTask\nNew",
        "Maintenance::CallbackTestTask\nNew",
        "Maintenance::CancelledEnqueueTask\nNew",
        "Maintenance::EnqueueErrorTask\nNew",
        "Maintenance::ErrorTask\nNew",
        "Maintenance::ParamsTask\nNew",
        "Maintenance::TestTask\nNew",
        "Maintenance::UpdatePostsInBatchesTask\nNew",
        "Maintenance::UpdatePostsModulePrependedTask\nNew",
        "Maintenance::UpdatePostsThrottledTask\nNew",
        "Completed Tasks",
        "Maintenance::ImportPostsTask\nSucceeded",
      ]

      assert_equal expected, page.all("h3").map(&:text)
    end

    test "show a Task" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsTask")

      assert_title "Maintenance::UpdatePostsTask"
      assert_text "Succeeded"
      assert_text "Ran for less than 5 seconds, finished 8 days ago."
    end

    test "show a Task with active and completed runs" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsTask")

      assert_title "Maintenance::UpdatePostsTask"
      assert_text "Paused"

      assert_equal ["Active Runs", "Previous Runs"], page.all("h4").map(&:text)
      runs = page.all("h5").map(&:text)
      assert_includes runs, "July 18, 2022 11:05\nPaused"
      assert_includes runs, "January 01, 2020 01:00\nSucceeded"
    end

    test "task with attributes renders default values on the form" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")

      content_text = page.find_field("[task_arguments][content]").text
      assert_equal("default content", content_text)
      integer_attr_val = page.find_field("[task_arguments][integer_attr]").value
      assert_equal("111222333", integer_attr_val)
    end

    test "task with attributes renders correct field tags on the form" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")

      content_field = page.find_field("[task_arguments][content]")
      assert_equal("textarea", content_field.tag_name)
      integer_field = page.find_field("[task_arguments][integer_attr]")
      assert_equal("input", integer_field.tag_name)
      assert_equal("number", integer_field[:type])
      big_integer_field = page.find_field("[task_arguments][big_integer_attr]")
      assert_equal("input", big_integer_field.tag_name)
      assert_equal("number", big_integer_field[:type])
      float_field = page.find_field("[task_arguments][float_attr]")
      assert_equal("input", float_field.tag_name)
      assert_equal("number", float_field[:type])
      decimal_field = page.find_field("[task_arguments][decimal_attr]")
      assert_equal("input", decimal_field.tag_name)
      assert_equal("number", decimal_field[:type])
      datetime_field = page.find_field("[task_arguments][datetime_attr]")
      assert_equal("input", datetime_field.tag_name)
      assert_equal("datetime-local", datetime_field[:type])
      date_field = page.find_field("[task_arguments][date_attr]")
      assert_equal("input", date_field.tag_name)
      assert_equal("date", date_field[:type])
      time_field = page.find_field("[task_arguments][time_attr]")
      assert_equal("input", time_field.tag_name)
      assert_equal("time", time_field[:type])
      boolean_field = page.find_field("[task_arguments][boolean_attr]")
      assert_equal("input", boolean_field.tag_name)
      assert_equal("checkbox", boolean_field[:type])
    end

    test "view a Task with multiple pages of Runs" do
      Run.create!(
        task_name: "Maintenance::TestTask",
        created_at: 1.hour.ago,
        started_at: 1.hour.ago,
        tick_count: 2,
        tick_total: 10,
        status: :errored,
        ended_at: 1.hour.ago,
      )
      21.times do |i|
        Run.create!(
          task_name: "Maintenance::TestTask",
          created_at: i.minutes.ago,
          started_at: i.minutes.ago,
          tick_count: 10,
          tick_total: 10,
          status: :succeeded,
          ended_at: i.minutes.ago,
        )
      end

      visit maintenance_tasks_path

      click_on("Maintenance::TestTask")
      assert_no_text "Errored"

      click_on("Next page")
      assert_text "Errored"
      assert_no_link "Next page"
    end

    test "show a deleted Task" do
      visit maintenance_tasks_path + "/tasks/Maintenance::DeletedTask"

      assert_title "Maintenance::DeletedTask"
      assert_text "Succeeded"
      assert_button "Run", disabled: true
    end

    test "visit main page through iframe" do
      visit root_path

      within_frame("maintenance-tasks-iframe") do
        assert_content "Maintenance Tasks"
      end
    end
  end
end
