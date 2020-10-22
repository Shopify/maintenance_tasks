# frozen_string_literal: true
module MaintenanceTasks
  # Model that persists information related to a task being run from the UI.
  class Run < ApplicationRecord
    # Various statuses a run can be in:
    #
    # enqueued      The task has been enqueued by the user.
    # running       The task is being performed by a job worker.
    # succeeded     The task finished without error.
    # cancelled     The user explicitly halted the task's execution.
    # interrupted   The task was interrupted by the job infrastructure.
    # paused        The task was paused in the middle of the run by the user.
    # errored       The task code produced an unhandled exception.
    STATUSES = [
      :enqueued,
      :running,
      :succeeded,
      :cancelled,
      :interrupted,
      :paused,
      :errored,
    ]

    ACTIVE_STATUSES = [:enqueued, :running, :paused]

    enum status: STATUSES.to_h { |status| [status, status.to_s] }

    validates :task_name, inclusion: { in: ->(_) {
      Task.available_tasks.map(&:to_s)
    } }

    serialize :backtrace

    scope :active, -> { where(status: ACTIVE_STATUSES) }

    validates_with RunStatusValidator, on: :update

    # Enqueues the job after validating and persisting the run.
    def enqueue
      if save
        TaskJob.perform_later(self)
      end
    end

    # Increments +tick_count+ by +number_of_ticks+, directly in the DB.
    # The attribute value is not set in the current instance, you need
    # to reload the record.
    #
    # @param number_of_ticks [Integer] number of ticks to add to tick_count.
    def increment_ticks(number_of_ticks)
      self.class.update_counters(id, tick_count: number_of_ticks, touch: true)
    end
  end
end
