# frozen_string_literal: true

module MaintenanceTasks
  # Shared cursor logic for ActiveRecord-based enumerators.
  #
  # @api private
  module ActiveRecordCursor
    private

    def build_scope(cursor)
      @ordered_scope ||= @relation.reorder(@columns.map { |col| arel_table[col].asc })
      return @ordered_scope if cursor.nil?

      cursor_values = Array(cursor)
      @ordered_scope.where(cursor_conditions(cursor_values))
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
