# frozen_string_literal: true

module MaintenanceTasks
  # @api private
  class CsvBatchEnumerator
    include Enumerable

    def initialize(csv, batch_size:, cursor: nil)
      @csv = csv
      @batch_size = batch_size
      @cursor = cursor
    end

    # @return [Integer] the total number of items.
    def size
      count = @csv.count
      (count + @batch_size - 1) / @batch_size
    end

    # Yields each item with its cursor value.
    def each
      return to_enum(:each) unless block_given?

      batch = []
      batch_index = 0

      @csv.each do |row|
        batch << row
        next if batch.size < @batch_size

        if @cursor.nil? || batch_index > @cursor
          yield batch, batch_index
        end
        batch = []
        batch_index += 1
      end

      if batch.any?
        if @cursor.nil? || batch_index > @cursor
          yield batch, batch_index
        end
      end
    end
  end
end
