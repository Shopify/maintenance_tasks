# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskOutputTest < ActiveSupport::TestCase
    class TestTaskWithOutput < Task
      def collection
        [1, 2, 3]
      end

      def process(item)
        log_output("Processing item #{item}")
        log_output("Item #{item} squared is #{item * item}")
      end
    end

    class NoCollectionTaskWithOutput < Task
      no_collection

      def process
        log_output("Starting task")
        log_output("Task completed")
      end
    end

    test "task logs output during processing" do
      run = Run.create!(task_name: "MaintenanceTasks::TaskOutputTest::TestTaskWithOutput")
      task = TestTaskWithOutput.new
      task.instance_variable_set(:@run, run)

      task.process(5)
      run.reload

      assert_equal "Processing item 5\nItem 5 squared is 25", run.output
    end

    test "output accumulates across multiple process calls" do
      run = Run.create!(task_name: "MaintenanceTasks::TaskOutputTest::TestTaskWithOutput")
      task = TestTaskWithOutput.new
      task.instance_variable_set(:@run, run)

      task.process(1)
      task.process(2)
      run.reload

      expected_output = "Processing item 1\nItem 1 squared is 1\n" \
        "Processing item 2\nItem 2 squared is 4"
      assert_equal expected_output, run.output
    end

    test "no collection task can log output" do
      run = Run.create!(task_name: "MaintenanceTasks::TaskOutputTest::NoCollectionTaskWithOutput")
      task = NoCollectionTaskWithOutput.new
      task.instance_variable_set(:@run, run)

      task.process
      run.reload

      assert_equal "Starting task\nTask completed", run.output
    end

    test "log_output does nothing when run is not set" do
      task = TestTaskWithOutput.new

      # Should not raise error
      assert_nothing_raised do
        task.process(1)
      end
    end

    test "run appends output correctly" do
      run = Run.create!(task_name: "MaintenanceTasks::TaskOutputTest::TestTaskWithOutput")

      run.append_output("First line")
      run.reload
      assert_equal "First line", run.output

      run.append_output("Second line")
      run.reload
      assert_equal "First line\nSecond line", run.output
    end

    test "output persists across run status changes" do
      run = Run.create!(task_name: "MaintenanceTasks::TaskOutputTest::TestTaskWithOutput")

      run.append_output("Test output content")
      assert_equal "Test output content", run.reload.output

      run.running!
      assert_equal "Test output content", run.reload.output

      run.succeeded!
      assert_equal "Test output content", run.reload.output
    end

    test "append_output handles nil output column gracefully" do
      # Simulate missing output column by stubbing column_names
      columns_without_output = Run.column_names.dup - ["output"]
      Run.stubs(:column_names).returns(columns_without_output)
      run = Run.create!(task_name: "MaintenanceTasks::TaskOutputTest::TestTaskWithOutput")

      # Should not raise error
      assert_nothing_raised do
        run.append_output("Test")
      end
    ensure
      Run.unstub(:column_names)
    end
  end
end
