# frozen_string_literal: true

module MaintenanceTasks
  # Class handles rendering the maintenance_tasks page in the host application.
  # It makes data about available, enqueued, performing, and completed
  # tasks accessible to the views so it can be displayed in the UI.
  #
  # @api private
  class TasksController < ApplicationController
    before_action :set_refresh, only: [:index]

    # Renders the maintenance_tasks/tasks page, displaying
    # available tasks to users, grouped by category.
    def index
      @available_tasks = TaskDataIndex.available_tasks.group_by(&:category)
    end

    # Renders the page responsible for providing Task actions to users.
    # Shows running and completed instances of the Task.
    def show
      task_name = params.fetch(:id)
      @task = TaskDataShow.new(task_name)
      @task.active_runs.load
      set_refresh if @task.active_runs.any?
      @runs_page = RunsPage.new(@task.completed_runs, params[:cursor])
      if @task.active_runs.none? && @runs_page.records.none?
        Task.named(task_name)
      end
    end

    private

    def set_refresh
      @refresh = true
    end
  end
end
