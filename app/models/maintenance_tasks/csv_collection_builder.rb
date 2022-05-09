# frozen_string_literal: true

require "csv"

module MaintenanceTasks
  # Strategy for building a Task that processes CSV files.
  #
  # @api private
  class CsvCollectionBuilder
    attr_accessor :csv_sample

    # Defines the collection to be iterated over, based on the provided CSV.
    #
    # @return [CSV] the CSV object constructed from the specified CSV content,
    #   with headers.
    def collection(task)
      CSV.new(task.csv_content, headers: true)
    end

    # The number of rows to be processed. Excludes the header row from the
    # count and assumes a trailing newline is at the end of the CSV file.
    # Note that this number is an approximation based on the number of
    # newlines.
    #
    # @return [Integer] the approximate number of rows to process.
    def count(task)
      task.csv_content.count("\n") - 1
    end

    # Return that the Task processes CSV content.
    def has_csv_content?
      true
    end

    # Returns that the Task processes a collection.
    def no_collection?
      false
    end

    # Checks if CSV sample is present on the task.
    #
    # @return [boolean] true if sample is present, false otherwise.

    def has_csv_sample?
      csv_sample.present?
    end
  end
end
