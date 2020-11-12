# frozen_string_literal: true
require 'test_helper'

class MaintenanceTasksTest < ActiveSupport::TestCase
  test '.tasks_module defaults to constant Maintenance' do
    assert_equal Maintenance, MaintenanceTasks.tasks_module
  end

  test '.tasks_module can be set' do
    previous_task_module = MaintenanceTasks.tasks_module.name

    Object.const_set('Task', Module.new {})
    MaintenanceTasks.tasks_module = 'Task'
    assert_equal(Task, MaintenanceTasks.tasks_module)
  ensure
    MaintenanceTasks.tasks_module = previous_task_module
    Object.send(:remove_const, :Task)
  end

  test '.job can be set' do
    original_job = MaintenanceTasks.job.name
    MaintenanceTasks.job = 'CustomTaskJob'
    assert_equal(CustomTaskJob, MaintenanceTasks.job)
  ensure
    MaintenanceTasks.job = original_job
  end

  test "doesn't leak its internals" do
    expected_public_constants = [
      :Engine,  # to mount
      :Runner,  # to run a Task
      :Task,    # to define tasks
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
