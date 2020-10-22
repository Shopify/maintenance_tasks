# frozen_string_literal: true
module MaintenanceTasks
  # Custom validator class responsible for ensuring that transitions between
  # Run statuses are valid.
  class RunStatusValidator < ActiveModel::Validator
    # Valid status transitions a Run can make.
    VALID_STATUS_TRANSITIONS = {
      'enqueued' => ['running', 'paused', 'cancelled'],
      'running' => [
        'succeeded',
        'paused',
        'cancelled',
        'interrupted',
        'errored',
      ],
      'paused' => ['enqueued'],
      'interrupted' => ['running', 'succeeded'],
    }

    # Validate whether a transition from one Run status
    # to another is acceptable.
    #
    #  @param record [MaintenanceTasks::Run] the Run object being validated.
    def validate(record)
      previous_status = record.status_was
      new_status = record.status

      return if previous_status == new_status

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
end
