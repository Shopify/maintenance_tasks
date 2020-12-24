# frozen_string_literal: true
require 'test_helper'

class MaintenanceTasksTest < ActiveSupport::TestCase
  test '.tasks_module defaults to constant Maintenance' do
    assert_equal('Maintenance', MaintenanceTasks.tasks_module)
  end

  test '.tasks_module can be set' do
    previous_task_module = MaintenanceTasks.tasks_module

    MaintenanceTasks.tasks_module = 'Task'
    assert_equal('Task', MaintenanceTasks.tasks_module)
  ensure
    MaintenanceTasks.tasks_module = previous_task_module
  end

  test '.tasks_location defaults to "tasks"' do
    assert_equal('tasks', MaintenanceTasks.tasks_location)
  end

  test '.tasks_location can be set' do
    previous_task_location = MaintenanceTasks.tasks_location

    MaintenanceTasks.tasks_location = 'jobs'
    assert_equal('jobs', MaintenanceTasks.tasks_location)
  ensure
    MaintenanceTasks.tasks_location = previous_task_location
  end

  test '.job can be set' do
    original_job = MaintenanceTasks.job.name
    MaintenanceTasks.job = 'CustomTaskJob'
    assert_equal(CustomTaskJob, MaintenanceTasks.job)
  ensure
    MaintenanceTasks.job = original_job
  end

  test '.configure_bugsnag_integration keeps original error handler if no Bugsnag' do
    original_error_handler = MaintenanceTasks.error_handler
    MaintenanceTasks.configure_bugsnag_integration
    assert_equal original_error_handler, MaintenanceTasks.error_handler
  end

  test '.configure_bugsnag_integration configures error handler to notify Bugsnag if Bugsnag in use' do
    previous_error_handler = MaintenanceTasks.error_handler

    # Stub Bugsnag being installed on host application
    Object.const_set(:Bugsnag, Class.new)
    main_self = TOPLEVEL_BINDING.receiver
    main_self.expects(:require).with('bugsnag').returns(true)

    Bugsnag.expects(:notify).with('Something went wrong')
    MaintenanceTasks.configure_bugsnag_integration
    MaintenanceTasks.error_handler.call('Something went wrong')
  ensure
    MaintenanceTasks.error_handler = previous_error_handler
    Object.send(:remove_const, :Bugsnag)
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
