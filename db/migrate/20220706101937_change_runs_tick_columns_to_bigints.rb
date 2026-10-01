# frozen_string_literal: true

class ChangeRunsTickColumnsToBigints < ActiveRecord::Migration[7.0]
  def up
    change_table(:maintenance_tasks_runs, bulk: true) do |t|
      # SQLite drops unstated options on t.change; restate default/null.
      t.change(:tick_count, :bigint, default: 0, null: false)
      t.change(:tick_total, :bigint)
    end
  end

  def down
    change_table(:maintenance_tasks_runs, bulk: true) do |t|
      t.change(:tick_count, :integer, default: 0, null: false)
      t.change(:tick_total, :integer)
    end
  end
end
