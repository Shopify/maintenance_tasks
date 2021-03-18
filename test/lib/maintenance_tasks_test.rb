# frozen_string_literal: true
require "test_helper"

class MaintenanceTasksTest < ActiveSupport::TestCase
  test "deprecation warning raised when error_handler does not accept three arguments" do
    error_handler_before = MaintenanceTasks.error_handler

    dep_msg = "MaintenanceTasks.error_handler should be a lambda that takes "\
    "three arguments: error, task_context, and errored_element."
    assert_deprecated(dep_msg) { MaintenanceTasks.error_handler = ->(error) {} }
  ensure
    MaintenanceTasks.error_handler = error_handler_before
  end
end
