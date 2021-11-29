class AddCreatorAndApprovalToMaintenanceTasksRuns < ActiveRecord::Migration[6.1]
  def change
    add_column(:maintenance_tasks_runs, :creator, :string)
    add_column(:maintenance_tasks_runs, :approver, :string)
  end
end
