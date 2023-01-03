# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class TaskDataShowTest < ActiveSupport::TestCase
    test "#code returns the code source of the Task" do
      task_data = TaskDataShow.new("Maintenance::UpdatePostsTask")

      assert_includes task_data.code,
        "class UpdatePostsTask < MaintenanceTasks::Task"
    end

    test "#code returns the code source of a Task with a prepended module" do
      task_data = TaskDataShow.new("Maintenance::UpdatePostsModulePrependedTask")

      assert_includes task_data.code,
        "class UpdatePostsModulePrependedTask < MaintenanceTasks::Task"
    end

    test "#code returns nil if the Task does not exist" do
      task_data = TaskDataShow.new("Maintenance::DoesNotExist")
      assert_nil task_data.code
    end

    test "#to_s returns the name of the Task" do
      task_data = TaskDataShow.new("Maintenance::UpdatePostsTask")

      assert_equal "Maintenance::UpdatePostsTask", task_data.to_s
    end

    test "#completed_runs returns all completed Runs for the Task" do
      run_1 = maintenance_tasks_runs(:update_posts_task)

      run_2 = Run.create!(
        task_name: "Maintenance::UpdatePostsTask",
        status: :succeeded,
      )

      Run.create!(task_name: "Maintenance::UpdatePostsTask")

      task_data = TaskDataShow.new("Maintenance::UpdatePostsTask")

      assert_equal 2, task_data.completed_runs.count
      assert_equal run_2, task_data.completed_runs.first
      assert_equal run_1, task_data.completed_runs.last
    end

    test "#completed_runs is empty when there are no Runs for the Task" do
      Run.destroy_all

      task_data = TaskDataShow.new("Maintenance::UpdatePostsTask")

      assert_empty task_data.completed_runs
    end

    test "#deleted? returns true if the Task does not exist" do
      assert_predicate TaskDataShow.new("Maintenance::DoesNotExist"), :deleted?
    end

    test "#deleted? returns false for an existing Task" do
      refute_predicate TaskDataShow.new("Maintenance::UpdatePostsTask"), :deleted?
    end

    test "#csv_task? returns true if the Task includes the CsvTask module" do
      assert_predicate TaskDataShow.new("Maintenance::ImportPostsTask"), :csv_task?
    end

    test "#csv_task? returns false if the Task does not include the CsvTask module" do
      refute_predicate TaskDataShow.new("Maintenance::UpdatePostsTask"), :csv_task?
    end

    test "#csv_task? returns false if the Task is deleted" do
      refute_predicate TaskDataShow.new("Maintenance::DoesNotExist"), :csv_task?
    end

    test "#parameter_names returns list of parameter names for Tasks supporting parameters" do
      assert_equal(
        [
          "post_ids",
          "content",
          "integer_attr",
          "big_integer_attr",
          "float_attr",
          "decimal_attr",
          "datetime_attr",
          "date_attr",
          "time_attr",
          "boolean_attr",
        ],
        TaskDataShow.new("Maintenance::ParamsTask").parameter_names,
      )
    end

    test "#parameter_names returns empty list for deleted Tasks" do
      names = TaskDataShow.new("Maintenance::DoesNotExist").parameter_names
      assert_equal [], names
    end

    test "#new returns a Task instance" do
      assert_kind_of Task, TaskDataShow.new("Maintenance::ParamsTask").new
    end

    test "#new returns nil for a deleted Task" do
      assert_nil TaskDataShow.new("Maintenance::DoesNotExist").new
    end
  end
end
