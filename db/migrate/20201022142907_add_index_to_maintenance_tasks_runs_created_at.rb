# frozen_string_literal: true
class AddIndexToMaintenanceTasksRunsCreatedAt < ActiveRecord::Migration[6.0]
  def change
    add_index(:maintenance_tasks_runs, :created_at)
  end
end
