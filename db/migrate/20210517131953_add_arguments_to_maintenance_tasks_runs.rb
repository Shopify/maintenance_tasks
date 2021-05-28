# frozen_string_literal: true
class AddArgumentsToMaintenanceTasksRuns < ActiveRecord::Migration[6.0]
  def change
    add_column(:maintenance_tasks_runs, :arguments, :text)
  end
end
