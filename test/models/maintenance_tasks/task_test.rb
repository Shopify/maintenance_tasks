# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    test ".load_all returns list of tasks that inherit from the Task superclass" do
      expected = [
        "Maintenance::BatchImportPostsTask",
        "Maintenance::CallbackTestTask",
        "Maintenance::CancelledEnqueueTask",
        "Maintenance::CustomEnumeratingTask",
        "Maintenance::EnqueueErrorTask",
        "Maintenance::ErrorTask",
        "Maintenance::ImportPostsTask",
        "Maintenance::ImportPostsWithEncodingTask",
        "Maintenance::ImportPostsWithOptionsTask",
        "Maintenance::Nested::NestedMore::NestedMoreTask",
        "Maintenance::Nested::NestedTask",
        "Maintenance::NoCollectionTask",
        "Maintenance::ParamsTask",
        "Maintenance::TestTask",
        "Maintenance::UpdatePostsInBatchesTask",
        "Maintenance::UpdatePostsModulePrependedTask",
        "Maintenance::UpdatePostsTask",
        "Maintenance::UpdatePostsThrottledTask",
      ]
      # Filter out anonymous classes (nil names) created by other tests
      actual = MaintenanceTasks::Task.load_all.map(&:name).compact.sort
      assert_equal expected, actual
    end

    test ".available_tasks raises a deprecation warning before calling .load_all" do
      expected_warning =
        "MaintenanceTasks::Task.available_tasks is deprecated and will be " \
          "removed from maintenance-tasks 3.0.0. Use .load_all instead.\n"

      Warning.expects(:warn).with(expected_warning, category: :deprecated)
      Task.expects(:load_all)

      Task.available_tasks
    end

    test ".named returns the task based on its name" do
      expected_task = Maintenance::UpdatePostsTask
      assert_equal expected_task, Task.named("Maintenance::UpdatePostsTask")
    end

    test ".named raises Not Found Error if the task doesn't exist" do
      error = assert_raises(Task::NotFoundError) do
        Task.named("Maintenance::DoesNotExist")
      end
      assert error.message
        .start_with?("Task Maintenance::DoesNotExist not found.")
      assert_equal "Maintenance::DoesNotExist", error.name
    end

    test ".named raises Not Found Error if the name doesn't refer to a Task" do
      error = assert_raises(Task::NotFoundError) do
        Task.named("Array")
      end
      assert error.message.start_with?("Array is not a Task.")
      assert_equal "Array", error.name
    end

    test ".process calls #process" do
      item = mock
      Maintenance::TestTask.any_instance.expects(:process).with(item)
      Maintenance::TestTask.process(item)
    end

    test ".collection calls #collection" do
      assert_equal [1, 2], Maintenance::TestTask.collection
    end

    test ".count calls #count" do
      assert_equal :no_count, Maintenance::TestTask.count
    end

    test "#count is :no_count by default" do
      task = Task.new
      assert_equal(:no_count, task.count)
    end

    test "#collection raises NoMethodError" do
      error = assert_raises(NoMethodError) { Task.new.collection }
      message = "MaintenanceTasks::Task must implement `collection`."
      assert error.message.start_with?(message)
    end

    test "#process raises NoMethodError" do
      error = assert_raises(NoMethodError) { Task.new.process("an item") }
      message = "MaintenanceTasks::Task must implement `process`."
      assert error.message.start_with?(message)
    end

    test ".throttle_conditions inherits conditions from superclass" do
      assert_equal [], Maintenance::TestTask.throttle_conditions
    end

    test ".throttle_on registers throttle condition for Task" do
      throttle_condition = -> { true }

      Maintenance::TestTask.throttle_on(&throttle_condition)

      task_throttle_conditions = Maintenance::TestTask.throttle_conditions
      assert_equal(1, task_throttle_conditions.size)

      condition = task_throttle_conditions.first
      assert_equal(throttle_condition, condition[:throttle_on])
      assert_equal(30.seconds, condition[:backoff].call)
    ensure
      Maintenance::TestTask.throttle_conditions = []
    end

    test ".cursor_columns returns nil" do
      task = Task.new
      assert_nil task.cursor_columns
    end

    test ".status_reload_frequency defaults to global configuration" do
      task = Task.new
      assert_equal MaintenanceTasks.status_reload_frequency, task.status_reload_frequency
    end

    test ".status_reload_frequency uses task-level override when configured" do
      original_reload_frequency = Maintenance::TestTask.status_reload_frequency
      Maintenance::TestTask.reload_status_every(5.seconds)
      task = Maintenance::TestTask.new

      assert_equal(5.seconds, task.status_reload_frequency)
    ensure
      Maintenance::TestTask.status_reload_frequency = original_reload_frequency
    end

    test ".parallelized? returns false by default" do
      refute Task.parallelized?
      refute Task.new.parallelized?
    end

    test ".parallelize sets parallelized to true" do
      task_class = Class.new(Task) do
        parallelize
      end

      assert task_class.parallelized?
      assert task_class.new.parallelized?
    end

    test "#process_item raises NoMethodError when parallelize is used but not implemented" do
      task_class = Class.new(Task) do
        parallelize

        def collection
          [1, 2, 3].each_slice(3)
        end
      end

      task = task_class.new
      batch = task.collection.first

      error = assert_raises(NoMethodError) do
        task.process(batch)
      end

      assert_includes error.message, "must implement `process_item(item)`"
    end

    test "#process handles parallel processing when parallelized" do
      task_class = Class.new(Task) do
        parallelize

        attr_accessor :processed_items

        def initialize
          super
          @processed_items = Concurrent::Array.new
        end

        def collection
          [1, 2, 3].each_slice(3)
        end

        def process_item(item)
          @processed_items << item
        end
      end

      task = task_class.new
      batch = task.collection.first
      task.process(batch)

      assert_equal [1, 2, 3].sort, task.processed_items.sort
    end

    test "#process raises NoMethodError for non-parallelized task without process implementation" do
      error = assert_raises(NoMethodError) { Task.new.process("an item") }
      message = "MaintenanceTasks::Task must implement `process`."
      assert error.message.start_with?(message)
    end

    test "parallelized task stores errored element on exception" do
      task_class = Class.new(Task) do
        parallelize

        def collection
          [1, 2, 3].each_slice(3)
        end

        def process_item(item)
          raise StandardError, "Error on item #{item}" if item == 2
        end
      end

      task = task_class.new
      batch = task.collection.first

      assert_raises(StandardError) do
        task.process(batch)
      end

      assert_equal 2, task.instance_variable_get(:@errored_element)
    end
  end
end
