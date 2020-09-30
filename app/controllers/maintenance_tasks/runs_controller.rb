# frozen_string_literal: true

module MaintenanceTasks
  # Class handles rendering the maintenance_tasks page in the host application.
  # It communicates with the Run model to persist info related to task runs.
  # It makes data about available, enqueued, performing, and completed
  # tasks accessible to the views so it can be displayed in the UI.
  class RunsController < ApplicationController
    # Renders the /maintenance_tasks page, displaying available tasks to users.
    def index
      @available_tasks = Task.descendants
    end

    # POST /maintenance_tasks/runs
    #
    # Takes a name parameter which is the name of the MaintenanceTask to run.
    def create
      task_name = params.require(:name)
      if Run.enqueue_task_named(task_name)
        redirect_to(root_path, notice: "Task #{task_name} enqueued.")
      else
        redirect_to(root_path, notice: "Task #{task_name} does not exist.")
      end
    end
  end
end
