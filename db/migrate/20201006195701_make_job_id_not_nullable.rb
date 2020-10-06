# frozen_string_literal: true
class MakeJobIdNotNullable < ActiveRecord::Migration[6.0]
  def change
    change_column_null(:maintenance_tasks_runs, :job_id, false)
  end
end
