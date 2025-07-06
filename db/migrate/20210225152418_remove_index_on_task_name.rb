# frozen_string_literal: true

class RemoveIndexOnTaskName < ActiveRecord::Migration[7.0]
  def up
    change_table(:maintenance_tasks_runs) do |t|
      t.remove_index(:task_name)
    end
  end

  def down
    change_table(:maintenance_tasks_runs) do |t|
      t.index(:task_name)
    end
  end
end
