# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskDataTest < ActiveSupport::TestCase
    test ".find returns a TaskData for an existing Task" do
      task_data = TaskData.find("Maintenance::UpdatePostsTask")
      assert_equal "Maintenance::UpdatePostsTask", task_data.name
    end

    test ".find returns a TaskData for a deleted Task with a Run" do
      task_data = TaskData.find("Maintenance::DeletedTask")
      assert_equal "Maintenance::DeletedTask", task_data.name
    end

    test ".find raises if the Task does not exist" do
      assert_raises Task::NotFoundError do
        TaskData.find("Maintenance::DoesNotExist")
      end
    end

    test ".available_tasks returns a list of Tasks as TaskData, ordered alphabetically by name" do
      expected = [
        "Maintenance::BatchImportPostsTask",
        "Maintenance::CallbackTestTask",
        "Maintenance::CancelledEnqueueTask",
        "Maintenance::EnqueueErrorTask",
        "Maintenance::ErrorTask",
        "Maintenance::ImportPostsTask",
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
      assert_equal expected, TaskData.available_tasks.map(&:name)
    end

    test "#new sets last_run if one is passed as an argument" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      task_data = TaskData.new("Maintenance::UpdatePostsTask", run)

      assert_equal "Maintenance::UpdatePostsTask", task_data.to_s
    end

    test "#code returns the code source of the Task" do
      task_data = TaskData.new("Maintenance::UpdatePostsTask")

      assert_includes task_data.code,
        "class UpdatePostsTask < MaintenanceTasks::Task"
    end

    test "#code returns the code source of a Task with a prepended module" do
      task_data = TaskData.new("Maintenance::UpdatePostsModulePrependedTask")

      assert_includes task_data.code,
        "class UpdatePostsModulePrependedTask < MaintenanceTasks::Task"
    end

    test "#code returns nil if the Task does not exist" do
      task_data = TaskData.new("Maintenance::DoesNotExist")
      assert_nil task_data.code
    end

    test "#to_s returns the name of the Task" do
      task_data = TaskData.new("Maintenance::UpdatePostsTask")

      assert_equal "Maintenance::UpdatePostsTask", task_data.to_s
    end

    test "#completed_runs returns all completed Runs for the Task" do
      run_1 = maintenance_tasks_runs(:update_posts_task)

      run_2 = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :succeeded,
      )

      Run.create!(task_name: "Maintenance::UpdatePostsTask")

      task_data = TaskData.find("Maintenance::UpdatePostsTask")

      assert_equal 2, task_data.completed_runs.count
      assert_equal run_2, task_data.completed_runs.first
      assert_equal run_1, task_data.completed_runs.last
    end

    test "#completed_runs is empty when there are no Runs for the Task" do
      Run.destroy_all

      task_data = TaskData.find("Maintenance::UpdatePostsTask")

      assert_empty task_data.completed_runs
    end

    test "#deleted? returns true if the Task does not exist" do
      assert_predicate TaskData.new("Maintenance::DoesNotExist"), :deleted?
    end

    test "#deleted? returns false for an existing Task" do
      refute_predicate TaskData.new("Maintenance::UpdatePostsTask"), :deleted?
    end

    test "#status is new when Task does not have any Runs" do
      task_data = TaskData.new("Maintenance::UpdatePostsTask")
      assert_equal "new", task_data.status
    end

    test "#status is the latest Run status" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :paused,
      )
      task_data = TaskData.new("Maintenance::UpdatePostsTask", run)
      assert_equal "paused", task_data.status
    end

    test "#category returns :active if the task is active" do
      run = Run.create!(task_name: "Maintenance::UpdatePostsTask")
      task_data = TaskData.new("Maintenance::UpdatePostsTask", run)
      assert_equal :active, task_data.category
    end

    test "#category returns :new if the task is new" do
      assert_equal :new, TaskData.new("Maintenance::SomeNewTask").category
    end

    test "#category returns :completed if the task is completed" do
      run = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :succeeded,
      )
      task_data = TaskData.new("Maintenance::UpdatePostsTask", run)
      assert_equal :completed, task_data.category
    end

    test "#csv_task? returns true if the Task includes the CsvTask module" do
      assert_predicate TaskData.new("Maintenance::ImportPostsTask"), :csv_task?
    end

    test "#csv_task? returns false if the Task does not include the CsvTask module" do
      refute_predicate TaskData.new("Maintenance::UpdatePostsTask"), :csv_task?
    end

    test "#csv_task? returns false if the Task is deleted" do
      refute_predicate TaskData.new("Maintenance::DoesNotExist"), :csv_task?
    end

    test "#parameter_names returns list of parameter names for Tasks supporting parameters" do
      assert_equal(
        [
          "post_ids", "content", "integer_attr", "big_integer_attr",
          "float_attr", "decimal_attr", "datetime_attr", "date_attr",
          "time_attr", "boolean_attr",
        ],
        TaskData.new("Maintenance::ParamsTask").parameter_names,
      )
    end

    test "#parameter_names returns empty list for deleted Tasks" do
      names = TaskData.new("Maintenance::DoesNotExist").parameter_names
      assert_equal [], names
    end

    test "#new returns a Task instance" do
      assert_kind_of Task, TaskData.new("Maintenance::ParamsTask").new
    end

    test "#new returns nil for a deleted Task" do
      assert_nil TaskData.new("Maintenance::DoesNotExist").new
    end
  end
end
