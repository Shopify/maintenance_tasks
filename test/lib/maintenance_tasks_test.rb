# frozen_string_literal: true
require 'test_helper'

class MaintenanceTasksTest < ActiveSupport::TestCase
  test "doesn't leak its internals" do
    expected_public_constants = [
      :Engine,  # to mount
      :Runner,  # to run a Task
      :Task,    # to define Tasks
      :TaskJob, # to customize the job
    ]
    public_constants = MaintenanceTasks.constants.select do |constant|
      constant =
        eval("MaintenanceTasks::#{constant}") # rubocop:disable Security/Eval
      next if constant.is_a?(Class) && constant < Minitest::Test
      true
    rescue NameError
      false
    end
    assert_equal expected_public_constants.sort, public_constants.sort
  end

  test 'deprecation warning raised when error_handler does not accept three arguments' do
    error_handler_before = MaintenanceTasks.error_handler

    dep_msg = 'MaintenanceTasks.error_handler should be a lambda that takes '\
    'three arguments: error, task_context, and errored_element.'
    assert_deprecated(dep_msg) { MaintenanceTasks.error_handler = ->(error) {} }
  ensure
    MaintenanceTasks.error_handler = error_handler_before
  end
end
