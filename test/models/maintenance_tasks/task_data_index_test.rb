# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskDataIndexTest < ActiveSupport::TestCase
    test ".available_tasks returns a list of Tasks as TaskDataShow, ordered alphabetically by name" do
      expected = [
        "Maintenance::ArchivedTask",
        "Maintenance::BatchImportPostsTask",
        "Maintenance::CallbackTestTask",
        "Maintenance::CancelledEnqueueTask",
        "Maintenance::EnqueueErrorTask",
        "Maintenance::ErrorTask",
        "Maintenance::ImportPostsTask",
        "Maintenance::Nested::NestedMore::NestedMoreTask",
        "Maintenance::Nested::NestedTask",
        "Maintenance::NoCollectionTask",
        # duplicate due to fixtures containing two active runs of this task
        "Maintenance::NoCollectionTask",
        "Maintenance::ParamsTask",
        "Maintenance::TestTask",
        "Maintenance::UpdatePostsInBatchesTask",
        "Maintenance::UpdatePostsModulePrependedTask",
        "Maintenance::UpdatePostsTask",
        "Maintenance::UpdatePostsThrottledTask",
      ]
      assert_equal expected, TaskDataIndex.available_tasks.map(&:name)
    end

    test "#new sets last_run if one is passed as an argument" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", false, run)

      assert_equal "Maintenance::UpdatePostsTask", task_data.to_s
    end

    test "#to_s returns the name of the Task" do
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", false)

      assert_equal "Maintenance::UpdatePostsTask", task_data.to_s
    end

    test "#status is archived when Task is archived" do
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", true)
      assert_equal "archived", task_data.status
    end

    test "#status is new when Task does not have any Runs and is not archived" do
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", false)
      assert_equal "new", task_data.status
    end

    test "#status is the latest Run status if the Task is not archived" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :paused,
      )
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", false, run)
      assert_equal "paused", task_data.status
    end

    test "#category returns :active if the task is active" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", false, run)
      assert_equal :active, task_data.category
    end

    test "#category returns :new if the task is new" do
      assert_equal :new, TaskDataIndex.new("Maintenance::SomeNewTask", false).category
    end

    test "#category returns :completed if the task is completed" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :succeeded,
      )
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", false, run)
      assert_equal :completed, task_data.category
    end

    test "#category returns :archived if the task is archived" do
      assert_equal :archived, TaskDataIndex.new("Maintenance::SomeNewTask", true).category
    end
  end
end
