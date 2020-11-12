# frozen_string_literal: true

module MaintenanceTasks
  # Class communicates with the Run model to persist info related to task runs.
  # It defines actions for creating and pausing runs.
  #
  # @api private
  class RunsController < ApplicationController
    before_action :set_run, only: [:pause, :cancel, :resume]
    before_action :set_task

    # Updates a Run status to paused.
    def pause
      @run.pausing!
      redirect_to(task_path(@task))
    end

    # Updates a Run status to cancelling.
    def cancel
      @run.cancelling!
      redirect_to(task_path(@task))
    end

    private

    def set_run
      @run = Run.find(params.fetch(:id))
    end

    def set_task
      @task = Task.named(params.fetch(:task_id))
    end
  end
  private_constant :RunsController
end
