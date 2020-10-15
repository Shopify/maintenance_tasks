# frozen_string_literal: true

module MaintenanceTasks
  # Class handles rendering the maintenance_tasks page in the host application.
  # It communicates with the Run model to persist info related to task runs.
  # It makes data about available, enqueued, performing, and completed
  # tasks accessible to the views so it can be displayed in the UI.
  class RunsController < ApplicationController
    # Renders the /maintenance_tasks page, displaying available tasks to users.
    def index
      @runs = Run.all
      @tasks = Task.available_tasks
    end

    # POST /maintenance_tasks/runs
    #
    # Creates a new Run with the given parameters.
    def create
      run = Run.new(run_params)
      if run.enqueue
        redirect_to(root_path, notice: "Task #{run.task_name} enqueued.")
      else
        redirect_to(root_path, notice: run.errors.full_messages.join(' '))
      end
    end

    # Updates a Run status to paused.
    def pause
      run = Run.find(params.fetch(:id))
      run.paused!
      redirect_to(root_path)
    end

    # Updates a Run status from paused to running.
    def resume
      run = Run.find(params.fetch(:id))
      run.enqueued!
      run.enqueue
      redirect_to(root_path)
    end

    private

    def run_params
      params.require(:run).permit(:task_name)
    end
  end
end
