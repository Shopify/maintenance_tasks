# frozen_string_literal: true

module MaintenanceTasks
  # Class communicates with the Run model to persist info related to task runs.
  # It defines actions for creating and pausing runs.
  #
  # @api private
  class RunsController < ApplicationController
    before_action :set_run, except: :create

    # Creates a Run for a given Task and redirects to the Task page.
    def create(&block)
      task = Runner.run(
        name: params.fetch(:task_id),
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

    # Resumes a previously paused Run.
    def resume
      Runner.resume(@run)
      redirect_to(task_path(@run.task_name))
    rescue ActiveRecord::RecordInvalid => error
      redirect_to(task_path(@run.task_name), alert: error.message)
    rescue Runner::EnqueuingError => error
      redirect_to(task_path(@run.task_name), alert: error.message)
    end

    private

    def set_run
      @run = Run.find(params.fetch(:id))
    end
  end
end
