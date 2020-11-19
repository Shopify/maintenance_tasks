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

    # Increments +tick_count+ by +number_of_ticks+, directly in the DB.
    # The attribute value is not set in the current instance, you need
    # to reload the record.
    #
    # @param number_of_ticks [Integer] number of ticks to add to tick_count.
    def increment_ticks(number_of_ticks)
      self.class.update_counters(id, tick_count: number_of_ticks, touch: true)
    end

    # Refreshes just the status attribute on the Active Record object, and
    # ensures ActiveModel::Dirty does not mark the object as changed.
    # This allows us to get the Run's most up-to-date status without needing
    # to reload the entire record.
    #
    # @return [MaintenanceTasks::Run] the Run record with its updated status.
    def reload_status
      updated_status = Run.uncached do
        Run.where(id: id).pluck(:status).first
      end
      self.status = updated_status
      clear_attribute_changes([:status])
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

    # Adjusts the Run's time_running attribute.
    #
    # If the Run was previously paused, time_running is calculated as the
    # existing time_running plus the time between now and when the Run resumed.
    #
    # If the Run has never been paused, time_running is calculated as the time
    # between now and when the Run started.
    #
    # Note that the time a Run spends interrupted is counted towards its
    # time_running value.
    def adjust_time_running
      self.time_running = if last_resumed_at?
        time_running + (Time.now - last_resumed_at)
      else
        Time.now - started_at
      end
    end

    # Returns the estimated time the task will finish based on the the number of
    # ticks left and the average time needed to process a tick.
    # Returns nil if the Run is completed, or if the tick_count or tick_total is
    # zero.
    #
    # @return [Time] the estimated time the Run will finish.
    def estimated_completion_time
      return if completed? || tick_count == 0 || tick_total.to_i == 0

      time_elapsed = if paused?
        time_running
      elsif last_resumed_at?
        Time.now - last_resumed_at + time_running
      else
        Time.now - started_at
      end

      processed_per_second = tick_count.to_f / time_elapsed
      ticks_left = tick_total - tick_count
      seconds_to_finished = ticks_left / processed_per_second
      Time.now + seconds_to_finished
    end

    # Cancels a Run.
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
    end
  end
  private_constant :Run
end
