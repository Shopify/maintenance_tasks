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
end
