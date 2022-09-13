# frozen_string_literal: true

require "csv"

module MaintenanceTasks
  # Strategy for building a Task that processes CSV files in batches.
  #
  # @api private
  class BatchCsvCollectionBuilder < CsvCollectionBuilder
    BatchCsv = Struct.new(:csv, :batch_size, keyword_init: true)

    # Initialize a BatchCsvCollectionBuilder with a batch size.
    #
    # @param batch_size [Integer] the number of CSV rows in a batch.
    def initialize(batch_size)
      @batch_size = batch_size
      super()
    end

    # Defines the collection to be iterated over, based on the provided CSV.
    # Includes the CSV and the batch size.
    def collection(task)
      BatchCsv.new(
        csv: CSV.new(task.csv_content, headers: true),
        batch_size: @batch_size,
      )
    end

    # The number of batches to be processed. Excludes the header row from the
    # count and assumes a trailing newline is at the end of the CSV file.
    # Note that this number is an approximation based on the number of
    # newlines.
    #
    # @return [Integer] the approximate number of batches to process.
    def count(task)
      count = task.csv_content.count("\n") - 1
      (count + @batch_size - 1) / @batch_size
    end
  end
end
