# frozen_string_literal: true

require 'csv'

module MaintenanceTasks
  # Module that is included into Task classes by Task.csv_collection for
  # processing CSV files.
  #
  # @api private
  module CsvCollection
    # The contents of a CSV file to be processed by a Task.
    #
    # @return [String] the content of the CSV file to process.
    attr_accessor :csv_content

    # Defines the collection to be iterated over, based on the provided CSV.
    #
    # @return [CSV] the CSV object constructed from the specified CSV content,
    #   with headers.
    def collection
      CSV.new(csv_content, headers: true)
    end

    # The number of rows to be processed. Excludes the header row from the count
    # and assumed a trailing new line in the CSV file. Note that this number is
    # an approximation based on the number of new lines.
    #
    # @return [Integer] the approximate number of rows to process.
    def count
      csv_content.count("\n") - 1
    end
  end
end
