# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskDataIndexTest < ActiveSupport::TestCase
    test ".available_tasks returns a list of Tasks as TaskDataShow, ordered alphabetically by name" do
      expected = [
        "Maintenance::BatchImportPostsTask",
        "Maintenance::CallbackTestTask",
        "Maintenance::CancelledEnqueueTask",
        "Maintenance::CompositePrimaryKeyModelTask",
        "Maintenance::CustomEnumeratingTask",
        "Maintenance::EnqueueErrorTask",
        "Maintenance::ErrorTask",
        "Maintenance::ImportPostsTask",
        "Maintenance::ImportPostsWithEncodingTask",
        "Maintenance::ImportPostsWithOptionsTask",
        "Maintenance::Nested::NestedMore::NestedMoreTask",
        "Maintenance::Nested::NestedTask",
        "Maintenance::NoCollectionTask",
        # duplicate due to fixtures containing two active runs of this task
        "Maintenance::NoCollectionTask",
        "Maintenance::ParamsTask",
        "Maintenance::StaleTask",
        "Maintenance::TestTask",
        "Maintenance::UpdatePostsInBatchesTask",
        "Maintenance::UpdatePostsModulePrependedTask",
        "Maintenance::UpdatePostsTask",
        "Maintenance::UpdatePostsThrottledTask",
      ]
      assert_equal expected, TaskDataIndex.available_tasks.map(&:name)
    end

    test ".available_tasks assigns related run by most recent created completed run" do
      tasks = TaskDataIndex.available_tasks
      task = tasks.find { |task| task.name == "Maintenance::ImportPostsTask" }

      assert_equal maintenance_tasks_runs(:import_posts_task_succeeded), task.related_run
    end

    test "#new sets last_run if one is passed as an argument" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", run)

      assert_equal "Maintenance::UpdatePostsTask", task_data.to_s
    end

    test "#to_s returns the name of the Task" do
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask")

      assert_equal "Maintenance::UpdatePostsTask", task_data.to_s
    end

    test "#stale? returns `true` for tasks outside of the staleness threshold for the related_run" do
      MaintenanceTasks.with(task_staleness_threshold: 1.day) do
        run = Run.create!(
          task_name: "Maintenance::UpdatePostsTask",
          ended_at: 2.days.ago,
          status: :succeeded,
        )
        task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", run)
        assert task_data.stale?
      end
    end

    test "#stale? returns `false` for tasks with no related run" do
      MaintenanceTasks.with(task_staleness_threshold: 1.day) do
        task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", nil)
        refute task_data.stale?
      end
    end

    test "#status is new when Task does not have any Runs" do
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask")
      assert_equal "new", task_data.status
    end

    test "#status is the latest Run status" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :paused,
      )
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", run)
      assert_equal "paused", task_data.status
    end

    test "#category returns :active if the task is active" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", run)
      assert_equal :active, task_data.category
    end

    test "#category returns :new if the task is new" do
      assert_equal :new, TaskDataIndex.new("Maintenance::SomeNewTask").category
    end

    test "#category returns :completed if the task is completed" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :succeeded,
      )
      task_data = TaskDataIndex.new("Maintenance::UpdatePostsTask", run)
      assert_equal :completed, task_data.category
    end
  end
end
