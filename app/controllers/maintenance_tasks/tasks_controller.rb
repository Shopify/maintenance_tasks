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
      @available_tasks = TaskData.available_tasks.group_by(&:category)
    end

    # Renders the page responsible for providing Task actions to users.
    # Shows running and completed instances of the Task.
    def show
      @task = TaskData.find(params.fetch(:id))
      set_refresh if @task.last_run&.active?
      @runs_page = RunsPage.new(@task.previous_runs, params[:cursor])
    end

    # Runs a given Task and redirects to the Task page.
    def run(&block)
      task = Runner.run(
        name: params.fetch(:id),
        csv_file: params[:csv_file],
        arguments: params.fetch(:task_arguments, {}).permit!.to_h,
        &block
      )
      redirect_to(task_path(task))
    rescue ActiveRecord::RecordInvalid => error
      redirect_to(task_path(error.record.task_name), alert: error.message)
    rescue ActiveRecord::ValueTooLong => error
      task_name = params.fetch(:id)
      redirect_to(task_path(task_name), alert: error.message)
    rescue Runner::EnqueuingError => error
      redirect_to(task_path(error.run.task_name), alert: error.message)
    end

    private

    def set_refresh
      @refresh = true
    end
  end
end
