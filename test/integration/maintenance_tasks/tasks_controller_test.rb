# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TasksControllerTest < ActionDispatch::IntegrationTest
    test "task list auto-refreshes by default" do
      get maintenance_tasks_path

      assert_response :success
      assert_select "[data-refresh=true]"
    end

    test "task list does not auto-refresh when refresh=false is passed" do
      get maintenance_tasks_path, params: { refresh: "false" }

      assert_response :success
      assert_select "[data-refresh=true]", false
    end

    test "task list shows a link to disable auto-refresh when refreshing" do
      get maintenance_tasks_path

      assert_response :success
      assert_select "a[href*='refresh=false']", text: "Disable auto-refresh"
    end

    test "task list shows a link to enable auto-refresh when not refreshing" do
      get maintenance_tasks_path, params: { refresh: "false" }

      assert_response :success
      assert_select "a[href='/maintenance_tasks/']", text: "Enable auto-refresh"
    end
  end
end
