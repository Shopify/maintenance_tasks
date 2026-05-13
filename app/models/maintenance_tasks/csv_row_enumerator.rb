# frozen_string_literal: true

module MaintenanceTasks
  # @api private
  class CsvRowEnumerator
    include Enumerable

    def initialize(csv, cursor: nil)
      @csv = csv
      @cursor = cursor
    end

    # @return [Integer] the total number of items.
    def size
      @csv.count
    end

    # Yields each item with its cursor value.
    def each
      return to_enum(:each) unless block_given?

      @csv.each_with_index do |row, index|
        next if @cursor && index < @cursor + 1

        yield row, index
      end
    end
  end
end
