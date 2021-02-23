# frozen_string_literal: true

module MaintenanceTasks
  # Class communicates with the Run model to persist info related to task runs.
  # It defines actions for creating and pausing runs.
  #
  # @api private
  class RunsController < ApplicationController
    before_action :set_run

    # Updates a Run status to paused.
    def pause
      @run.pausing!
      redirect_to(task_path(@run.task_name))
    rescue ActiveRecord::RecordInvalid => error
      redirect_to(task_path(@run.task_name), alert: error.message)
    end

    # Updates a Run status to cancelling.
    def cancel
      @run.cancel
      redirect_to(task_path(@run.task_name))
    rescue ActiveRecord::RecordInvalid => error
      redirect_to(task_path(@run.task_name), alert: error.message)
    end

    private

    def set_run
      @run = Run.find(params.fetch(:id))
    end
  end
end
