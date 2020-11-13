# frozen_string_literal: true

require 'test_helper'

module MaintenanceTasks
  class RunnerTest < ActiveSupport::TestCase
    setup do
      @name = 'Maintenance::UpdatePostsTask'
      @run = mock
      @runner = Runner.new
    end

    test '#run creates a Run for the given Task name and enqueues the Run' do
      Run.expects(:new).with(task_name: @name).returns(@run)
      @run.expects(enqueue: true)

      @runner.run(name: @name)
    end

    test '#run raises a Run Error with validation errors when Run enqueue fails' do
      Run.expects(:new).with(task_name: @name).returns(@run)
      @run.expects(enqueue: false)
      @run.expects(errors: mock(full_messages: ['error 1', 'error 2']))

      error = assert_raises(Runner::RunError) do
        @runner.run(name: @name)
      end
      assert_equal 'error 1 error 2', error.message
    end
  end
end
