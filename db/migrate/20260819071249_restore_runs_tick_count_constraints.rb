# frozen_string_literal: true

# Repairs tick_count constraints that SQLite may drop during the historical type change.
class RestoreRunsTickCountConstraints < ActiveRecord::Migration[7.2]
  def up
    column = connection.columns(:maintenance_tasks_runs).find do |candidate|
      candidate.name == "tick_count"
    end
    return if [0, "0"].include?(column.default) && !column.null

    execute(<<~SQL.squish) if column.null
      UPDATE #{connection.quote_table_name(:maintenance_tasks_runs)}
      SET #{connection.quote_column_name(:tick_count)} = 0
      WHERE #{connection.quote_column_name(:tick_count)} IS NULL
    SQL

    change_column(
      :maintenance_tasks_runs,
      :tick_count,
      :bigint,
      default: 0,
      null: false,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "NULL tick counts were normalized to zero"
  end
end
