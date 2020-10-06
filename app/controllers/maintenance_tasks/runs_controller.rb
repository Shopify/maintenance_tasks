# frozen_string_literal: true

module MaintenanceTasks
  # Class handles rendering the maintenance_tasks page in the host application.
  # It communicates with the Run model to persist info related to task runs.
  # It makes data about available, enqueued, performing, and completed
  # tasks accessible to the views so it can be displayed in the UI.
  class RunsController < ApplicationController
    # Renders the /maintenance_tasks page, displaying available tasks to users.
    def index
      @tasks = Task.available_tasks
    end

    # POST /maintenance_tasks/runs
    #
    # Creates a new Run with the given parameters.
    def create
      task_name = run_params[:task_name]
      task = Task.named(task_name)
      if task
        task.perform_later
        redirect_to(root_path, notice: "Task #{task_name} enqueued.")
      else
        redirect_to(root_path, notice: "Task #{task_name} does not exist.")
      end
    end

    private

    def run_params
      params.require(:run).permit(:task_name)
    end
  end
end
