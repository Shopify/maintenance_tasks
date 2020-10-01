# frozen_string_literal: true
require 'test_helper'

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    test '.descendants returns list of tasks that inherit from the Task superclass' do
      expected_tasks = [Maintenance::UpdatePostsTask]
      assert_equal expected_tasks, MaintenanceTasks::Task.descendants
    end
  end
end
