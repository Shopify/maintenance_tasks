# frozen_string_literal: true

module MaintenanceTasks
  # Class communicates with the Run model to persist info related to task runs.
  # It defines actions for creating and pausing runs.
  class RunsController < ApplicationController
    before_action :set_run, only: [:pause, :cancel, :resume]
    before_action :set_task

    # POST /maintenance_tasks/runs
    #
    # Creates a new Run with the given parameters.
    def create
      run = Run.new(task_name: @task.name)
      if run.enqueue
        redirect_to(task_path(@task), notice: "Task #{run.task_name} enqueued.")
      else
        errors = run.errors.full_messages.join(' ')
        redirect_to(task_path(@task), notice: errors)
      end
    end

    # Updates a Run status to paused.
    def pause
      @run.paused!
      redirect_to(task_path(@task))
    end

    # Updates a Run status to cancelled.
    def cancel
      @run.cancelled!
      redirect_to(task_path(@task))
    end

    # Updates a Run status from paused to running.
    def resume
      @run.enqueued!
      @run.enqueue
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
end
