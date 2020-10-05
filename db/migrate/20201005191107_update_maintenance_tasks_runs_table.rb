# frozen_string_literal: true
class UpdateMaintenanceTasksRunsTable < ActiveRecord::Migration[6.0]
  def change
    change_table(:maintenance_tasks_runs) do |t|
      t.remove(:executions)

      t.string(:job_id)
      t.bigint(:cursor)
      t.string(:status, default: :enqueued, null: false)
      t.string(:error_class)
      t.string(:error_message)
      t.text(:stack_trace)
    end
  end
end
