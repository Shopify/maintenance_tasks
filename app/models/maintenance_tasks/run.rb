# frozen_string_literal: true
module MaintenanceTasks
  # Model that persists information related to a task being run from the UI.
  #
  # @api private
  class Run < ApplicationRecord
    # Various statuses a run can be in.
    STATUSES = [
      :enqueued,    # The task has been enqueued by the user.
      :running,     # The task is being performed by a job worker.
      :succeeded,   # The task finished without error.
      :cancelling,  # The task has been told to cancel but is finishing work.
      :cancelled,   # The user explicitly halted the task's execution.
      :interrupted, # The task was interrupted by the job infrastructure.
      :pausing,     # The task has been told to pause but is finishing work.
      :paused,      # The task was paused in the middle of the run by the user.
      :errored,     # The task code produced an unhandled exception.
    ]

    ACTIVE_STATUSES = [
      :enqueued,
      :running,
      :paused,
      :pausing,
      :cancelling,
      :interrupted,
    ]
    COMPLETED_STATUSES = [:succeeded, :errored, :cancelled]
    COMPLETED_RUNS_LIMIT = 10

    enum status: STATUSES.to_h { |status| [status, status.to_s] }

    validates :task_name, inclusion: { in: ->(_) {
      Task.available_tasks.map(&:to_s)
    } }

    serialize :backtrace

    scope :active, -> { where(status: ACTIVE_STATUSES) }
    scope :latest_completed, -> {
      where(status: COMPLETED_STATUSES)
        .order(created_at: :desc)
        .limit(COMPLETED_RUNS_LIMIT)
    }

    validates_with RunStatusValidator, on: :update

    # Sets the run status to enqueued, making sure the transition is validated
    # in case it's already enqueued.
    def enqueued!
      status_will_change!
      super
    rescue ActiveRecord::StaleObjectError
      reload_status
      retry
    end

    def start(task_count)
      update!(started_at: Time.now, tick_total: task_count)
    rescue ActiveRecord::StaleObjectError
      reload_status
      retry
    end

    # Cancels a Run, rescuing and retrying if an ActiveRecord::StaleObjectError
    # is encountered.
    #
    # If the Run is paused, it will transition directly to cancelled, since the
    # Task is not being performed. In this case, the ended_at timestamp
    # will be updated.
    #
    # If the Run is not paused, the Run will transition to cancelling.
    def cancel
      if paused?
        update!(status: :cancelled, ended_at: Time.now)
      else
        cancelling!
      end
    rescue ActiveRecord::StaleObjectError
      reload_status
      retry
    end

    # Sets the Run status to pausing, rescuing and retrying if an
    # ActiveRecord::StaleObjectError is encountered.
    def pausing!
      super
    rescue ActiveRecord::StaleObjectError
      reload_status
      retry
    end

    # Increments +tick_count+ by +number_of_ticks+ and +time_running+ by
    # +duration+, both directly in the DB.
    # The attribute values are not set in the current instance, you need
    # to reload the record.
    #
    # @param number_of_ticks [Integer] number of ticks to add to tick_count.
    # @param duration [Float] the time in seconds that elapsed since the last
    #   increment of ticks.
    def persist_progress(number_of_ticks, duration)
      self.class.update_counters(
        id,
        tick_count: number_of_ticks,
        time_running: duration,
        touch: true
      )
    end

    # Refreshes just the status and lock_version attributes on the ActiveRecord
    # object, and ensures ActiveModel::Dirty does not mark the object as
    # changed.
    # This allows us to get the Run's most up-to-date status without needing to
    # reload the entire record.
    #
    # @return [MaintenanceTasks::Run] the Run record with its updated status.
    def reload_status
      updated_status, updated_lock_version = Run.uncached do
        Run.where(id: id).pluck(:status, :lock_version).first
      end
      self.status = updated_status
      self.lock_version = updated_lock_version
      clear_attribute_changes([:status, :lock_version])
      self
    end

    # Returns whether the Run is stopping, which is defined as
    # having a status of pausing or cancelled.
    #
    # @return [Boolean] whether the Run is stopping.
    def stopping?
      pausing? || cancelling?
    end

    # Returns whether the Run has been started, which is indicated by the
    # started_at timestamp being present.
    #
    # @return [Boolean] whether the Run was started.
    def started?
      started_at.present?
    end

    # Returns whether the Run is completed, which is defined as
    # having a status of succeeded, cancelled, or errored.
    #
    # @return [Boolean] whether the Run is completed.
    def completed?
      COMPLETED_STATUSES.include?(status.to_sym)
    end

    # Returns the estimated time the task will finish based on the the number of
    # ticks left and the average time needed to process a tick.
    # Returns nil if the Run is completed, or if the tick_count or tick_total is
    # zero.
    #
    # @return [Time] the estimated time the Run will finish.
    def estimated_completion_time
      return if completed? || tick_count == 0 || tick_total.to_i == 0

      processed_per_second = (tick_count.to_f / time_running)
      ticks_left = (tick_total - tick_count)
      seconds_to_finished = ticks_left / processed_per_second
      Time.now + seconds_to_finished
    end
  end
  private_constant :Run
end
