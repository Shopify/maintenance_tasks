# frozen_string_literal: true
require 'test_helper'

class MaintenanceTasksTest < ActiveSupport::TestCase
  test '.tasks_module defaults to constant Maintenance' do
    assert_equal Maintenance, MaintenanceTasks.tasks_module
  end

  test '.tasks_module can be set' do
    Object.const_set('Task', Module.new {})
    MaintenanceTasks.tasks_module = 'Task'
    assert_equal(Task, MaintenanceTasks.tasks_module)
  ensure
    MaintenanceTasks.tasks_module = nil
    Object.send(:remove_const, :Task)
  end
end
