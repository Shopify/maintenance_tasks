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
        "Maintenance::NoCollectionTask Enqueued",
        "Maintenance::NoCollectionTask Paused",
        "Maintenance::UpdatePostsTask Paused",
        "New Tasks",
        "Maintenance::BatchImportPostsTask New",
        "Maintenance::CallbackTestTask New",
        "Maintenance::CancelledEnqueueTask New",
        "Maintenance::CustomEnumeratingTask New",
        "Maintenance::EnqueueErrorTask New",
        "Maintenance::ErrorTask New",
        "Maintenance::ImportPostsWithEncodingTask New",
        "Maintenance::ImportPostsWithOptionsTask New",
        "Maintenance::Nested::NestedMore::NestedMoreTask New",
        "Maintenance::Nested::NestedTask New",
        "Maintenance::ParamsTask New",
        "Maintenance::TestTask New",
        "Maintenance::UpdatePostsInBatchesTask New",
        "Maintenance::UpdatePostsModulePrependedTask New",
        "Maintenance::UpdatePostsThrottledTask New",
        "Completed Tasks",
        "Maintenance::ImportPostsTask Succeeded",
      ]

      assert_equal expected, page.all("h3").map(&:text)
    end

    test "show a Task" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsTask")

      assert_title "Maintenance::UpdatePostsTask"
      assert_selector "time", text: "January 01, 2020" do |tag|
        assert_equal "2020-01-01 01:00:00 UTC", tag[:title]
      end
      assert_text "Succeeded"
      assert_text "Ran for less than 5 seconds, finished 8 days ago."
    end

    test "show a Task with active and completed runs" do
      visit maintenance_tasks_path

      click_on("Maintenance::UpdatePostsTask")

      assert_title "Maintenance::UpdatePostsTask"
      assert_text "Paused"

      assert_equal ["Active Runs", "Previous Runs"], page.all("h4").map(&:text)
      assert_text(/July 18, 2022 11:05 Paused #\d/)
      assert_text(/January 01, 2020 01:00 Succeeded #\d/)
    end

    test "task with attributes renders default values on the form" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")

      content_text = page.find_field("task[content]").text
      assert_equal("default content", content_text)
      integer_attr_val = page.find_field("task[integer_attr]").value
      assert_equal("111222333", integer_attr_val)
    end

    test "task with attributes renders correct field tags on the form" do
      visit maintenance_tasks_path

      click_on("Maintenance::ParamsTask")

      content_field = page.find_field("task[content]")
      assert_equal("textarea", content_field.tag_name)
      assert_equal("default content", content_field.value)
      integer_field = page.find_field("task[integer_attr]")
      assert_equal("input", integer_field.tag_name)
      assert_equal("number", integer_field[:type])
      assert_empty(integer_field[:step])
      assert_equal("111222333", integer_field.value)
      big_integer_field = page.find_field("task[big_integer_attr]")
      assert_equal("input", big_integer_field.tag_name)
      assert_equal("number", big_integer_field[:type])
      assert_empty(big_integer_field[:step])
      assert_equal("111222333", big_integer_field.value)
      float_field = page.find_field("task[float_attr]")
      assert_equal("input", float_field.tag_name)
      assert_equal("number", float_field[:type])
      assert_equal("any", float_field[:step])
      assert_equal("12.34", float_field.value)
      decimal_field = page.find_field("task[decimal_attr]")
      assert_equal("input", decimal_field.tag_name)
      assert_equal("number", decimal_field[:type])
      assert_equal("any", decimal_field[:step])
      assert_equal("12.34", decimal_field.value)
      datetime_field = page.find_field("task[datetime_attr]")
      assert_equal("input", datetime_field.tag_name)
      assert_equal("datetime-local", datetime_field[:type])
      assert_equal("", datetime_field.value)
      date_field = page.find_field("task[date_attr]")
      assert_equal("input", date_field.tag_name)
      assert_equal("date", date_field[:type])
      assert_equal("", date_field.value)
      time_field = page.find_field("task[time_attr]")
      assert_equal("input", time_field.tag_name)
      assert_equal("time", time_field[:type])
      assert_equal("", time_field.value)
      boolean_field = page.find_field("task[boolean_attr]")
      assert_equal("input", boolean_field.tag_name)
      assert_equal("checkbox", boolean_field[:type])
      assert_nil(boolean_field[:checked])

      [
        "integer_dropdown_attr",
        "integer_dropdown_attr_proc_no_arg",
        "integer_dropdown_attr_proc_arg",
        "integer_dropdown_attr_from_method",
        "integer_dropdown_attr_callable",
      ].each do |dropdown_integer_attr|
        integer_dropdown_field = page.find_field("task[#{dropdown_integer_attr}]")
        assert_equal("select", integer_dropdown_field.tag_name)
        assert_equal("select-one", integer_dropdown_field[:type])
        integer_dropdown_field_options = integer_dropdown_field.find_all("option").map { |option| option[:value] }
        assert_equal(["", "100", "200", "300"], integer_dropdown_field_options)
      end

      text_integer_field = page.find_field("task[text_integer_attr_unbounded_range]")
      assert_equal("input", text_integer_field.tag_name)
      assert_equal("number", text_integer_field[:type])
      assert_empty(text_integer_field[:step])
      assert_equal("", text_integer_field.value)
    end

    test "task with attributes renders correct field tags on the form with values from query params" do
      visit maintenance_tasks.task_path("Maintenance::ParamsTask", params: {
        content: "string content",
        integer_attr: 12,
        big_integer_attr: 123456789,
        float_attr: 12.34,
        decimal_attr: 43.21,
        datetime_attr: "1984-01-01T12:34:56",
        date_attr: "1984-01-01",
        time_attr: "12:34:56",
        boolean_attr: "true",
        integer_dropdown_attr: "200",
        boolean_dropdown_attr: "false",
      })

      content_field = page.find_field("task[content]")
      assert_equal("textarea", content_field.tag_name)
      assert_equal("string content", content_field.value)
      integer_field = page.find_field("task[integer_attr]")
      assert_equal("input", integer_field.tag_name)
      assert_equal("number", integer_field[:type])
      assert_empty(integer_field[:step])
      assert_equal("12", integer_field.value)
      big_integer_field = page.find_field("task[big_integer_attr]")
      assert_equal("input", big_integer_field.tag_name)
      assert_equal("number", big_integer_field[:type])
      assert_empty(big_integer_field[:step])
      assert_equal("123456789", big_integer_field.value)
      float_field = page.find_field("task[float_attr]")
      assert_equal("input", float_field.tag_name)
      assert_equal("number", float_field[:type])
      assert_equal("any", float_field[:step])
      assert_equal("12.34", float_field.value)
      decimal_field = page.find_field("task[decimal_attr]")
      assert_equal("input", decimal_field.tag_name)
      assert_equal("number", decimal_field[:type])
      assert_equal("any", decimal_field[:step])
      assert_equal("43.21", decimal_field.value)
      datetime_field = page.find_field("task[datetime_attr]")
      assert_equal("input", datetime_field.tag_name)
      assert_equal("datetime-local", datetime_field[:type])
      assert_equal("1984-01-01T12:34:56", datetime_field.value)
      date_field = page.find_field("task[date_attr]")
      assert_equal("input", date_field.tag_name)
      assert_equal("date", date_field[:type])
      assert_equal("1984-01-01", date_field.value)
      time_field = page.find_field("task[time_attr]")
      assert_equal("input", time_field.tag_name)
      assert_equal("time", time_field[:type])
      assert_equal("12:34:56.000", time_field.value)
      boolean_field = page.find_field("task[boolean_attr]")
      assert_equal("input", boolean_field.tag_name)
      assert_equal("checkbox", boolean_field[:type])
      assert_equal("true", boolean_field[:checked])

      integer_dropdown_field = page.find_field("task[integer_dropdown_attr]")
      assert_equal("select", integer_dropdown_field.tag_name)
      assert_equal("select-one", integer_dropdown_field[:type])
      assert_equal("200", integer_dropdown_field.value)
      integer_dropdown_field_options = integer_dropdown_field.find_all("option").map { |option| option[:value] }
      assert_equal(["100", "200", "300"], integer_dropdown_field_options)

      boolean_dropdown_field = page.find_field("task[boolean_dropdown_attr]")
      assert_equal("select", boolean_dropdown_field.tag_name)
      assert_equal("select-one", boolean_dropdown_field[:type])
      assert_equal("false", boolean_dropdown_field.value)
      boolean_dropdown_field_options = boolean_dropdown_field.find_all("option").map { |option| option[:value] }
      assert_equal(["", "true", "false"], boolean_dropdown_field_options)
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
