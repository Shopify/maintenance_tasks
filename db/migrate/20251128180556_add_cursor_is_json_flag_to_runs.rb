# frozen_string_literal: true

class AddCursorIsJsonFlagToRuns < ActiveRecord::Migration[7.1]
  def change
    add_column(:maintenance_tasks_runs, :cursor_is_json, :boolean)
  end
end
