# frozen_string_literal: true

require 'test_helper'
require 'maintenance_tasks/cli'

module MaintenanceTasks
  class CLITest < ActiveSupport::TestCase
    setup do
      @cli = CLI.new
    end

    test '.exit_on_failure? is true' do
      assert_predicate CLI, :exit_on_failure?
    end

    test '#perfom runs the given Task and prints a success message' do
      task = mock(name: 'MyTask')

      Runner.expects(:run).with(name: 'MyTask').returns(task)
      @cli.expects(:say_status).with(:success, 'MyTask was enqueued.', :green)

      @cli.perform('MyTask')
    end

    test '#perfom prints an error message when the runner raises' do
      Runner.expects(:run).with(name: 'Wrong').raises('Invalid!')
      @cli.expects(:say_status).with(:error, 'Invalid!', :red)

      @cli.perform('Wrong')
    end
  end
end
