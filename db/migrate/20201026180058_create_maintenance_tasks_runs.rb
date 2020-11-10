# frozen_string_literal: true
class CreateMaintenanceTasksRuns < ActiveRecord::Migration[6.0]
  def change
    create_table(:maintenance_tasks_runs) do |t|
      t.string(:task_name, null: false)
      t.datetime(:started_at)
      t.datetime(:ended_at)
      t.integer(:tick_count, default: 0, null: false)
      t.integer(:tick_total)
      t.string(:job_id)
      t.bigint(:cursor)
      t.string(:status, default: :enqueued, null: false)
      t.string(:error_class)
      t.string(:error_message)
      t.text(:backtrace)

      t.timestamps
    end
    add_index(:maintenance_tasks_runs, :created_at)
    add_index(:maintenance_tasks_runs, :started_at)
    add_index(:maintenance_tasks_runs, :ended_at)
  end
end
