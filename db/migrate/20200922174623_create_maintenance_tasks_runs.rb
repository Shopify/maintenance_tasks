# frozen_string_literal: true
class CreateMaintenanceTasksRuns < ActiveRecord::Migration[6.0]
  def change
    create_table(:maintenance_tasks_runs) do |t|
      t.string(:task_name, null: false)
      t.text(:executions)
      t.integer(:tick_count, default: 0, null: false)
      t.integer(:tick_total)

      t.timestamps
    end
  end
end
