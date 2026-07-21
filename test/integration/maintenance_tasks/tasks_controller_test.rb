# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TasksControllerTest < ActionDispatch::IntegrationTest
    # Maintenance::UpdatePostsTask has a paused (active) run, so its show page
    # refreshes by default.
    ACTIVE_TASK = "Maintenance::UpdatePostsTask"

    test "task page auto-refreshes by default when there are active runs" do
      get maintenance_tasks.task_path(ACTIVE_TASK)

      assert_response :success
      assert_select "[data-refresh=true]"
    end

    test "task page does not auto-refresh when refresh=false is passed" do
      get maintenance_tasks.task_path(ACTIVE_TASK), params: { refresh: "false" }

      assert_response :success
      assert_select "[data-refresh=true]", false
    end

    test "task page shows a link to disable auto-refresh when refreshing" do
      get maintenance_tasks.task_path(ACTIVE_TASK)

      assert_response :success
      assert_select "a[href*='refresh=false']", text: "Disable auto-refresh"
    end

    test "task page shows a link to enable auto-refresh when not refreshing" do
      get maintenance_tasks.task_path(ACTIVE_TASK), params: { refresh: "false" }

      assert_response :success
      assert_select "a", text: "Enable auto-refresh"
    end

    test "task page shows no auto-refresh toggle when there are no active runs" do
      get maintenance_tasks.task_path("Maintenance::ImportPostsTask")

      assert_response :success
      assert_select "a", text: "Disable auto-refresh", count: 0
      assert_select "a", text: "Enable auto-refresh", count: 0
    end
  end
end
