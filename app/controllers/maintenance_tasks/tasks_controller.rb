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
      all_tasks = TaskDataIndex.available_tasks
      @namespaces = helpers.extract_namespaces(all_tasks)
      @selected_namespace = params[:namespace]

      filtered_tasks = if @selected_namespace.present?
        all_tasks.select { |task| task.name.start_with?("#{@selected_namespace}::") }
      else
        all_tasks
      end

      @available_tasks = filtered_tasks.group_by(&:category)
    end

    # Renders the page responsible for providing Task actions to users.
    # Shows running and completed instances of the Task.
    def show
      @task = TaskDataShow.prepare(
        params.fetch(:id),
        runs_cursor: params[:cursor],
        arguments: params.except(:id, :controller, :action).permit!,
      )
    end

    private

    def set_refresh
      @refresh = true
    end
  end
end
