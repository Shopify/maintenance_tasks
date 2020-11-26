# frozen_string_literal: true
module MaintenanceTasks
  # Custom validator class responsible for ensuring that transitions between
  # Run statuses are valid.
  #
  # @api private
  class RunStatusValidator < ActiveModel::Validator
    # Valid status transitions a Run can make.
    VALID_STATUS_TRANSITIONS = {
      # enqueued -> running occurs when the task starts performing.
      # enqueued -> pausing occurs when the task is paused before starting.
      # enqueued -> cancelling occurs when the task is cancelled
      #   before starting.
      'enqueued' => ['running', 'pausing', 'cancelling'],
      # pausing -> paused occurs when the task actually halts performing and
      #   occupies a status of paused.
      # pausing -> cancelling occurs when the user cancels a task immediately
      #   after it was paused, such that the task had not actually halted yet.
      # pausing -> succeeded occurs when the task completes immediately after
      #   being paused. This can happen if the task is on its last iteration
      #   when it is paused, or if the task is paused after enqueue but has
      #   nothing in its collection to process.
      'pausing' => ['paused', 'cancelling', 'succeeded'],
      # cancelling -> cancelled occurs when the task actually halts performing
      #   and occupies a status of cancelled.
      # cancelling -> succeeded occurs when the task completes immediately after
      #   being cancelled. See description for pausing -> succeeded.
      'cancelling' => ['cancelled', 'succeeded'],
      # running -> succeeded occurs when the task completes successfully.
      # running -> pausing occurs when a user pauses the task as
      #   it's performing.
      # running -> cancelling occurs when a user cancels the task as
      #   it's performing.
      # running -> interrupted occurs when the job infra shuts down the task as
      #   it's performing.
      # running -> errored occurs when the job raises an exception when running.
      'running' => [
        'succeeded',
        'pausing',
        'cancelling',
        'interrupted',
        'errored',
      ],
      # paused -> enqueued occurs when the task is resumed after being paused.
      # paused -> cancelling when the user cancels the task after it is paused.
      # paused -> cancelled when the user cancels the task after it is paused.
      'paused' => ['enqueued', 'cancelling', 'cancelled'],
      # interrupted -> running occurs when the task is resumed after being
      #   interrupted by the job infrastructure.
      # interrupted -> pausing occurs when the task is paused by the user while
      #   it is interrupted.
      # interrupted -> cancelling occurs when the task is cancelled by the user
      #   while it is interrupted.
      'interrupted' => ['running', 'pausing', 'cancelling'],
    }

    # Validate whether a transition from one Run status
    # to another is acceptable.
    #
    #  @param record [MaintenanceTasks::Run] the Run object being validated.
    def validate(record)
      return unless (previous_status, new_status = record.status_change)

      valid_new_statuses = VALID_STATUS_TRANSITIONS.fetch(previous_status, [])

      unless valid_new_statuses.include?(new_status)
        add_invalid_status_error(record, previous_status, new_status)
      end
    end

    private

    def add_invalid_status_error(record, previous_status, new_status)
      record.errors.add(
        :status,
        "Cannot transition run from status #{previous_status} to #{new_status}"
      )
    end
  end
  private_constant :RunStatusValidator
end
