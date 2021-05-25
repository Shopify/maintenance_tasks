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

    validates :task_name, on: :create, inclusion: { in: ->(_) {
      Task.available_tasks.map(&:to_s)
    } }
    validate :csv_attachment_presence, on: :create

    attr_readonly :task_name

    serialize :backtrace
    serialize :arguments, JSON

    scope :active, -> { where(status: ACTIVE_STATUSES) }

    # Ensure ActiveStorage is in use before preloading the attachments
    scope :with_attached_csv, -> do
      return unless defined?(ActiveStorage)
      with_attached_csv_file if ActiveStorage::Attachment.table_exists?
    end

    validates_with RunStatusValidator, on: :update

    if MaintenanceTasks.active_storage_service.present?
      has_one_attached :csv_file,
        service: MaintenanceTasks.active_storage_service
    elsif respond_to?(:has_one_attached)
      has_one_attached :csv_file
    end

    # Sets the run status to enqueued, making sure the transition is validated
    # in case it's already enqueued.
    def enqueued!
      status_will_change!
      super
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

    # Marks the run as errored and persists the error data.
    #
    # @param error [StandardError] the Error being persisted.
    def persist_error(error)
      update!(
        status: :errored,
        error_class: error.class.to_s,
        error_message: error.message,
        backtrace: Rails.backtrace_cleaner.clean(error.backtrace),
        ended_at: Time.now,
      )
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

    # Returns whether the Run is stopped, which is defined as having a status of
    # paused, succeeded, cancelled, or errored.
    #
    # @return [Boolean] whether the Run is stopped.
    def stopped?
      completed? || paused?
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

    # Returns whether the Run is active, which is defined as
    # having a status of enqueued, running, pausing, cancelling,
    # paused or interrupted.
    #
    # @return [Boolean] whether the Run is active.
    def active?
      ACTIVE_STATUSES.include?(status.to_sym)
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

    # Cancels a Run.
    #
    # If the Run is paused, it will transition directly to cancelled, since the
    # Task is not being performed. In this case, the ended_at timestamp
    # will be updated.
    #
    # If the Run is not paused, the Run will transition to cancelling.
    #
    # If the Run is already cancelling, and has last been updated more than 5
    # minutes ago, it will transition to cancelled, and the ended_at timestamp
    # will be updated.
    def cancel
      if paused? || stuck?
        update!(status: :cancelled, ended_at: Time.now)
      else
        cancelling!
      end
    end

    # Returns whether a Run is stuck, which is defined as having a status of
    # cancelling, and not having been updated in the last 5 minutes.
    #
    # @return [Boolean] whether the Run is stuck.
    def stuck?
      cancelling? && updated_at <= 5.minutes.ago
    end

    # Performs validation on the presence of a :csv_file attachment.
    # A Run for a Task that uses CsvCollection must have an attached :csv_file
    # to be valid. Conversely, a Run for a Task that doesn't use CsvCollection
    # should not have an attachment to be valid. The appropriate error is added
    # if the Run does not meet the above criteria.
    def csv_attachment_presence
      if Task.named(task_name) < CsvCollection && !csv_file.attached?
        errors.add(:csv_file, "must be attached to CSV Task.")
      elsif !(Task.named(task_name) < CsvCollection) && csv_file.present?
        errors.add(:csv_file, "should not be attached to non-CSV Task.")
      end
    rescue Task::NotFoundError
      nil
    end

    # Fetches the attached ActiveStorage CSV file for the run. Checks first
    # whether the ActiveStorage::Attachment table exists so that we are
    # compatible with apps that are not using ActiveStorage.
    #
    # @return [ActiveStorage::Attached::One] the attached CSV file
    def csv_file
      return unless defined?(ActiveStorage)
      return unless ActiveStorage::Attachment.table_exists?
      super
    end
  end
end
