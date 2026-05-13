# frozen_string_literal: true

module MaintenanceTasks
  # @api private
  class OnceEnumerator
    include Enumerable

    def initialize(cursor: nil)
      @already_run = !cursor.nil?
    end

    # @return [Integer] the total number of items.
    def size
      1
    end

    # Yields each item with its cursor value.
    def each
      return to_enum(:each) { size } unless block_given?

      yield nil, nil unless @already_run
    end
  end
end
