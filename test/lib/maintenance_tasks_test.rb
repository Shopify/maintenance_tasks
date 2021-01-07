# frozen_string_literal: true
require 'test_helper'

class MaintenanceTasksTest < ActiveSupport::TestCase
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
    Mocha::Configuration.override(
      stubbing_non_public_method: :allow,
      stubbing_non_existent_method: :allow,
    ) do
      main_self.expects(:require).with('bugsnag').returns(true)
      Bugsnag.expects(:notify).with('Something went wrong')
    end

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
