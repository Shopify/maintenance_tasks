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

    test "#perform runs CSV task with supplied CSV when --csv option used" do
      task = mock(name: "MyCsvTask")
      csv_file_path = file_fixture("sample.csv")

      Runner.expects(:run)
        .with do |kwargs|
          assert_equal("MyCsvTask", kwargs[:name])
          assert_equal(csv_file_path.to_s, kwargs[:csv_file][:io].path)
          assert_equal({}, kwargs[:arguments])
        end
        .returns(task)

      assert_output(/success\s+MyCsvTask was enqueued\./) do
        CLI.start(["perform", "MyCsvTask", "--csv", csv_file_path])
      end
    end

    test "#perform runs CSV task with content from stdin" do
      task = mock(name: "MyCsvTask")
      csv_string = "foo,bar\n1,2\n"
      $stdin = StringIO.new(csv_string)

      Runner.expects(:run)
        .with do |kwargs|
          assert_equal("MyCsvTask", kwargs[:name])
          assert_equal(csv_string, kwargs[:csv_file][:io].read)
          assert_equal({}, kwargs[:arguments])
        end
        .returns(task)

      assert_output(/success\s+MyCsvTask was enqueued\./) do
        CLI.start(["perform", "MyCsvTask", "--csv"])
      end

      $stdin = STDIN
    end

    test "#perform prints error message when CSV file does not exist" do
      assert_output(/error\s+CSV file not found: foo\.csv/) do
        CLI.start(["perform", "MyCsvTask", "--csv", "foo.csv"])
      end
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
