# frozen_string_literal: true
module MaintenanceTasks
  # Model that persists information related to a task being run from the UI.
  class Run < ApplicationRecord
    # Various statuses a run can be in:
    #
    # enqueued      The task has been enqueued by the user.
    # running       The task is being performed by a job worker.
    # succeeded     The task finished without error.
    # aborted       The user explicitly halted the task's execution.
    # interrupted   The task was paused in the middle of the run by the user.
    # errored       The task code produced an unhandled exception.
    STATUSES = [
      :enqueued,
      :running,
      :succeeded,
      :aborted,
      :interrupted,
      :errored,
    ]

    enum status: STATUSES.to_h { |status| [status, status.to_s] }

    validate :task_exists?

    # Enqueues the job after validating and persisting the run.
    def enqueue
      if save
        task_class.perform_later(self)
      end
    end

    private

    def task_class
      Task.named(task_name)
    end

    def task_exists?
      unless task_class
        errors.add(:base, "Task #{task_name} does not exist.")
      end
    end
  end
end
