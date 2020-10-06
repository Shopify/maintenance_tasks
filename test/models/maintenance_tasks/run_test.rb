# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class RunTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test "invalid if the task doesn't exist" do
      run = Run.new(task_name: 'Maintenance::DoesNotExist')
      refute run.valid?
      expected_error = 'Task Maintenance::DoesNotExist does not exist.'
      assert_includes run.errors.full_messages, expected_error
    end
  end
end
