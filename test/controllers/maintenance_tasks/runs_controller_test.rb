# frozen_string_literal: true

require "test_helper"

module MaintenanceTasks
  class RunsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @running_run = Run.create!(task_name: "Maintenance::UpdatePostsTask", status: :running)
      @paused_run = Run.create!(task_name: "Maintenance::UpdatePostsTask", status: :paused)
    end

    test "pause transitions a run of the given task" do
      post pause_task_run_path("Maintenance::UpdatePostsTask", @running_run)

      assert_redirected_to task_path("Maintenance::UpdatePostsTask")
      assert_predicate @running_run.reload, :pausing?
    end

    test "pause responds with not found for a run belonging to another task" do
      post pause_task_run_path("Maintenance::TestTask", @running_run)

      assert_response :not_found
      assert_predicate @running_run.reload, :running?
    end

    test "cancel transitions a run of the given task" do
      post cancel_task_run_path("Maintenance::UpdatePostsTask", @running_run)

      assert_redirected_to task_path("Maintenance::UpdatePostsTask")
      assert_predicate @running_run.reload, :cancelling?
    end

    test "cancel responds with not found for a run belonging to another task" do
      post cancel_task_run_path("Maintenance::TestTask", @running_run)

      assert_response :not_found
      assert_predicate @running_run.reload, :running?
    end

    test "resume transitions a run of the given task" do
      post resume_task_run_path("Maintenance::UpdatePostsTask", @paused_run)

      assert_redirected_to task_path("Maintenance::UpdatePostsTask")
      assert_predicate @paused_run.reload, :enqueued?
    end

    test "resume responds with not found for a run belonging to another task" do
      Runner.expects(:resume).never

      post resume_task_run_path("Maintenance::TestTask", @paused_run)

      assert_response :not_found
      assert_predicate @paused_run.reload, :paused?
    end

    private

    def pause_task_run_path(...) = maintenance_tasks.pause_task_run_path(...)
    def cancel_task_run_path(...) = maintenance_tasks.cancel_task_run_path(...)
    def resume_task_run_path(...) = maintenance_tasks.resume_task_run_path(...)
    def task_path(...) = maintenance_tasks.task_path(...)
  end
end
