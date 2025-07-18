# frozen_string_literal: true

class AddOutputToMaintenanceTasksRuns < ActiveRecord::Migration[7.0]
  def change
    add_column(:maintenance_tasks_runs, :output, :text)
  end
end
