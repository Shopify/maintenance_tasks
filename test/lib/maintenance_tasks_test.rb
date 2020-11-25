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
    assert_equal expected_public_constants, public_constants(MaintenanceTasks)
    assert_equal [], public_constants(MaintenanceTasks::Runner)
    assert_equal [:NotFoundError], public_constants(MaintenanceTasks::Task)
  end

  def public_constants(a_module)
    a_module.constants.select do |constant|
      constant =
        eval("#{a_module}::#{constant}") # rubocop:disable Security/Eval
      next if constant.is_a?(Class) && constant < Minitest::Test
      true
    rescue NameError
      false
    end.sort
  end
end
