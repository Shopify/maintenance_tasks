# frozen_string_literal: true

module MaintenanceTasks
  # @api private
  class ActiveRecordBatchEnumerator
    include Enumerable

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
        scope = build_scope(cursor)
        batch_scope = scope.limit(@batch_size)
        records = batch_scope.to_a
        break if records.empty?

        last_record = records.last
        cursor = extract_cursor(last_record)
        yield batch_scope, cursor
      end
    end

    private

    def build_scope(cursor)
      scope = @relation.reorder(@columns.map { |col| arel_table[col].asc })
      return scope if cursor.nil?

      cursor_values = Array(cursor)
      scope.where(cursor_conditions(cursor_values))
    end

    def cursor_conditions(cursor_values)
      conditions = @columns.each_index.map do |i|
        eq_clauses = @columns[0...i].map.with_index do |col, j|
          arel_table[col].eq(cursor_values[j])
        end
        gt_clause = arel_table[@columns[i]].gt(cursor_values[i])

        if eq_clauses.empty?
          gt_clause
        else
          eq_clauses.reduce(:and).and(gt_clause)
        end
      end

      conditions.reduce(:or)
    end

    def extract_cursor(record)
      values = @columns.map { |col| record.public_send(col) }
      values.size == 1 ? values.first : values
    end

    def arel_table
      @relation.klass.arel_table
    end
  end
end
