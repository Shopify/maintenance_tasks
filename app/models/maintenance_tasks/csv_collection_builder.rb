# frozen_string_literal: true

require "csv"

module MaintenanceTasks
  # Strategy for building a Task that processes CSV files.
  #
  # @param csv_options [Hash] options to pass to the CSV parser.
  # @api private
  class CsvCollectionBuilder
    def initialize(**csv_options)
      @csv_options = csv_options
    end

    # Defines the collection to be iterated over, based on the provided CSV.
    #
    # @return [CSV] the CSV object constructed from the specified CSV content.
    def collection(task)
      CSV.new(task.csv_content, **@csv_options)
    end

    # The number of rows to be processed.
    # It uses the CSV library for an accurate row count.
    # Note that the entire file is loaded. It will take several seconds with files with millions of rows.
    #
    # @return [Integer] the approximate number of rows to process.
    def count(task)
      CSV.new(task.csv_content, **@csv_options).count
    end

    # Return that the Task processes CSV content.
    def has_csv_content?
      true
    end

    # Returns that the Task processes a collection.
    def no_collection?
      false
    end
  end
end
