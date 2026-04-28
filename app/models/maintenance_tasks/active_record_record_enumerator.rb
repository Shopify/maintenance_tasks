# frozen_string_literal: true

module MaintenanceTasks
  # @api private
  class ActiveRecordRecordEnumerator
    include Enumerable
    include ActiveRecordCursor

    DEFAULT_BATCH_SIZE = 100

    def initialize(relation, cursor: nil, columns: nil, batch_size: nil)
      @relation = relation
      @cursor = cursor
      @batch_size = batch_size || DEFAULT_BATCH_SIZE
      @columns = Array(columns || relation.primary_key).map(&:to_sym)
    end

    # @return [Integer] the total number of items.
    def size
      @relation.count
    end

    # Yields each item with its cursor value.
    def each
      return to_enum(:each) { size } unless block_given?

      cursor = @cursor
      loop do
        batch = build_scope(cursor).limit(@batch_size).to_a
        break if batch.empty?

        batch.each do |record|
          cursor = extract_cursor(record)
          yield record, cursor
        end
      end
    end
  end
end
