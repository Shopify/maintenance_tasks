# frozen_string_literal: true

module MaintenanceTasks
  # Model that persists information related to a task being run from the UI.
  #
  # @api private
  class Run < ApplicationRecord
    include RunConcern

    validate :csv_attachment_presence, on: :create
    validate :csv_content_type, on: :create

    # Ensure ActiveStorage is in use before preloading the attachments
    scope :with_attached_csv, -> do
      return unless defined?(ActiveStorage)

      with_attached_csv_file if ActiveStorage::Attachment.table_exists?
    end

    if MaintenanceTasks.active_storage_service.present?
      has_one_attached :csv_file,
        service: MaintenanceTasks.active_storage_service
    elsif respond_to?(:has_one_attached)
      has_one_attached :csv_file
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

    private

    # Performs validation on the presence of a :csv_file attachment.
    # A Run for a Task that uses CsvCollection must have an attached :csv_file
    # to be valid. Conversely, a Run for a Task that doesn't use CsvCollection
    # should not have an attachment to be valid. The appropriate error is added
    # if the Run does not meet the above criteria.
    def csv_attachment_presence
      if Task.named(task_name).has_csv_content? && !csv_file.attached?
        errors.add(:csv_file, "must be attached to CSV Task.")
      elsif !Task.named(task_name).has_csv_content? && csv_file.present?
        errors.add(:csv_file, "should not be attached to non-CSV Task.")
      end
    rescue Task::NotFoundError
      nil
    end

    # Performs validation on the content type of the :csv_file attachment.
    # A Run for a Task that uses CsvCollection must have a present :csv_file
    # and a content type of "text/csv" to be valid. The appropriate error is
    # added if the Run does not meet the above criteria.
    def csv_content_type
      if csv_file.present? && csv_file.content_type != "text/csv"
        errors.add(:csv_file, "must be a CSV")
      end
    rescue Task::NotFoundError
      nil
    end
  end
end
