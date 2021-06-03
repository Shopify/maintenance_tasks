# frozen_string_literal: true

require "test_helper"
require "maintenance_tasks/cli"

module MaintenanceTasks
  class CLITest < ActiveSupport::TestCase
    setup do
      @cli = CLI.new
    end

    test ".exit_on_failure? is true" do
      assert_predicate CLI, :exit_on_failure?
    end

    test "#perfom runs the given Task and prints a success message" do
      task = mock(name: "MyTask")

      Runner.expects(:run).with(name: "MyTask", csv_file: nil, arguments: {})
        .returns(task)
      @cli.expects(:say_status).with(:success, "MyTask was enqueued.", :green)

      @cli.perform("MyTask")
    end

    test "#perfom prints an error message when the runner raises" do
      Runner.expects(:run).with(name: "Wrong", csv_file: nil, arguments: {})
        .raises("Invalid!")
      @cli.expects(:say_status).with(:error, "Invalid!", :red)

      @cli.perform("Wrong")
    end

    test "#perform runs a CSV Task with the supplied CSV when --csv option used" do
      task = mock(name: "MyCsvTask")
      csv_file_path = file_fixture("sample.csv")
      opened_csv_file = File.open(csv_file_path)
      expected_attachable = { io: opened_csv_file, filename: "sample.csv" }

      @cli.expects(:options).at_least_once.returns(csv: csv_file_path)
      File.expects(:open).with(csv_file_path).returns(opened_csv_file)
      Runner.expects(:run)
        .with(name: "MyCsvTask", csv_file: expected_attachable, arguments: {})
        .returns(task)
      @cli.expects(:say_status)
        .with(:success, "MyCsvTask was enqueued.", :green)

      @cli.perform("MyCsvTask")
    end

    test "#perform runs a Task with the supplied arguments when --arguments option used" do
      task = mock(name: "MyParamsTask")
      arguments = { "post_ids": "1,2,3" }

      @cli.expects(:options).at_least_once.returns(arguments: arguments)
      Runner.expects(:run)
        .with(name: "MyParamsTask", csv_file: nil, arguments: arguments)
        .returns(task)
      @cli.expects(:say_status)
        .with(:success, "MyParamsTask was enqueued.", :green)

      @cli.perform("MyParamsTask")
    end
  end
end
