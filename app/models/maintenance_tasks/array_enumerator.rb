# frozen_string_literal: true

module MaintenanceTasks
  # @api private
  class ArrayEnumerator
    include Enumerable

    def initialize(array, cursor: nil)
      @array = array
      @start = cursor ? cursor + 1 : 0
    end

    # @return [Integer] the total number of items.
    def size
      @array.size
    end

    # Yields each item with its cursor value.
    def each
      return to_enum(:each) { size } unless block_given?

      @array[@start..].each_with_index do |element, offset|
        yield element, @start + offset
      end
    end
  end
end
