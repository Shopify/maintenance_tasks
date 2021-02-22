# frozen_string_literal: true
class ChangeCursorToString < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      change_table(:maintenance_tasks_runs) do |t|
        dir.up   { t.change(:cursor, :string) }
        dir.down { t.change(:cursor, :bigint) }
      end
    end
  end
end
