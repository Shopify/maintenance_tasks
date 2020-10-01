# frozen_string_literal: true

module MaintenanceTasks
  # Class handles rendering the maintenance_tasks page in the host application.
  # It communicates with the Run model to persist info related to task runs.
  # It makes data about available, enqueued, performing, and completed
  # tasks accessible to the views so it can be displayed in the UI.
  class RunsController < ApplicationController
    # Renders the /maintenance_tasks page, displaying available tasks to users
    def index
      @available_tasks = Task.descendants
    end
  end
end
