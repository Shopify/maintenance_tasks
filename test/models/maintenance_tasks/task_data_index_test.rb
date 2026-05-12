# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskDataIndexTest < ActiveSupport::TestCase
    test ".available_tasks orders completed tasks by most recent run first" do
      completed_tasks = TaskDataIndex.available_tasks.select { |task| task.category == :completed }

      assert_equal(
        ["Maintenance::StaleTask", "Maintenance::ImportPostsTask"],
        completed_tasks.map(&:name),
      )
    end

    test ".available_tasks orders active tasks by most recent run first, regardless of name order" do
      # TestTask sorts alphabetically BEFORE UpdatePostsThrottledTask, but we
      # give UpdatePostsThrottledTask the newer run so the test fails if the
      # code falls back to alphabetical-by-name ordering.
      Run.create!(task_name: "Maintenance::TestTask", status: :enqueued, created_at: 2.hours.ago)
      Run.create!(task_name: "Maintenance::UpdatePostsThrottledTask", status: :enqueued, created_at: 1.minute.ago)

      active_names = TaskDataIndex.available_tasks
        .select { |task| task.category == :active }
        .map(&:name)

      assert_equal(
        [
          "Maintenance::UpdatePostsThrottledTask",
          "Maintenance::TestTask",
          "Maintenance::NoCollectionTask",
          "Maintenance::NoCollectionTask",
          "Maintenance::UpdatePostsTask",
        ],
        active_names,
      )
    end

    test ".available_tasks orders new tasks alphabetically by name" do
      new_task_names = TaskDataIndex.available_tasks
        .select { |task| task.category == :new }
        .map(&:name)

      assert_equal new_task_names.sort, new_task_names
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
