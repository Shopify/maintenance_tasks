# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskTest < ActiveSupport::TestCase
    test ".available_tasks returns list of tasks that inherit from the Task superclass" do
      expected = [
        "Maintenance::BatchImportPostsTask",
        "Maintenance::CallbackTestTask",
        "Maintenance::CancelledEnqueueTask",
        "Maintenance::EnqueueErrorTask",
        "Maintenance::ErrorTask",
        "Maintenance::ImportPostsTask",
        "Maintenance::NoCollectionTask",
        "Maintenance::ParamsTask",
        "Maintenance::TestTask",
        "Maintenance::UpdatePostsInBatchesTask",
        "Maintenance::UpdatePostsModulePrependedTask",
        "Maintenance::UpdatePostsTask",
        "Maintenance::UpdatePostsThrottledTask",
      ]
      assert_equal expected,
        MaintenanceTasks::Task.available_tasks.map(&:name).sort
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
  end
end
