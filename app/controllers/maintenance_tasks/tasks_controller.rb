# frozen_string_literal: true

module MaintenanceTasks
  # Class handles rendering the maintenance_tasks page in the host application.
  # It makes data about available, enqueued, performing, and completed
  # tasks accessible to the views so it can be displayed in the UI.
  #
  # @api private
  class TasksController < ApplicationController
    before_action :set_refresh, only: [:index, :show]

    # Renders the maintenance_tasks/tasks page, displaying
    # available tasks to users.
    def index
      @tasks = Task.available_tasks
    end

    # Renders the page responsible for providing Task actions to users.
    # Shows running and completed instances of the Task.
    def show
      @task = Task.named(params.fetch(:id))
      @last_run = @task.last_run
      @pagy, @previous_runs = pagy(
        @task.runs.where.not(id: @last_run&.id).order(created_at: :desc)
      )
    end

    # Runs a given Task and redirects to the Task page.
    def run
      task = Runner.new.run(name: params.fetch(:id))
      redirect_to(task_path(task))
    rescue ActiveRecord::RecordInvalid => error
      redirect_to(task_path(error.record.task_name), alert: error.message)
    end

    private

    def set_refresh
      @refresh = 3
    end
  end
  private_constant :TasksController
end
