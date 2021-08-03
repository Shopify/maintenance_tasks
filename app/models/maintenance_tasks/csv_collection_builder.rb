# frozen_string_literal: true

require "csv"

module MaintenanceTasks
  # Strategy for building a Task that processes CSV files.
  #
  # @api private
  class CsvCollectionBuilder
    # Defines the collection to be iterated over, based on the provided CSV.
    #
    # @return [CSV] the CSV object constructed from the specified CSV content,
    #   with headers.
    def collection(task)
      CSV.new(task.csv_content, headers: true)
    end

    # The number of rows to be processed. Excludes the header row from the count
    # and assumed a trailing new line in the CSV file. Note that this number is
    # an approximation based on the number of new lines.
    #
    # @return [Integer] the approximate number of rows to process.
    def count(task)
      task.csv_content.count("\n") - 1
    end

    # Return that the Task processes CSV content.
    def has_csv_content?
      true
    end
  end
end
