# frozen_string_literal: true
module MaintenanceTasks
  # Class handles rendering the maintenance_tasks page in the host application.
  # It makes data about available, enqueued, performing, and completed
  # tasks accessible to the views so it can be displayed in the UI.
  class TasksController < MaintenanceTasks::ApplicationController
    # Renders the maintenance_tasks/tasks page, displaying
    # available tasks to users.
    def index
      @tasks = Task.available_tasks
      @pagy, @active_runs = pagy(Run.active.order(created_at: :desc))
    end

    # Renders the page responsible for providing Task actions to users.
    # Shows running and completed instances of the Task.
    def show
      @task = Task.named(params.fetch(:id))
      @pagy, @runs = pagy(@task.runs.order(created_at: :desc))
      @active_run = @task.active_run
    end
  end
end
