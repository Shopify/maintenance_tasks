# frozen_string_literal: true

module MaintenanceTasks
  # @api private
  class ActiveRecordBatchEnumerator
    include Enumerable
    include ActiveRecordCursor

    DEFAULT_BATCH_SIZE = 100

    def initialize(relation, cursor: nil, batch_size: nil, columns: nil)
      @relation = relation
      @cursor = cursor
      @batch_size = batch_size || DEFAULT_BATCH_SIZE
      @columns = Array(columns || relation.primary_key).map(&:to_sym)
    end

    # @return [Integer] the total number of items.
    def size
      count = @relation.count
      (count + @batch_size - 1) / @batch_size
    end

    # Yields each item with its cursor value.
    def each
      return to_enum(:each) { size } unless block_given?

      cursor = @cursor
      loop do
        batch_scope = build_scope(cursor).limit(@batch_size)
        records = batch_scope.to_a
        break if records.empty?

        cursor = extract_cursor(records.last)
        yield batch_scope, cursor
      end
    end
  end
end
