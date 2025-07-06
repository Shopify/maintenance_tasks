# frozen_string_literal: true

class AddArgumentsToMaintenanceTasksRuns < ActiveRecord::Migration[7.0]
  def change
    add_column(:maintenance_tasks_runs, :arguments, :text)
  end
end
