# frozen_string_literal: true

class AddMetadataToRuns < ActiveRecord::Migration[6.0]
  def change
    add_column(:maintenance_tasks_runs, :metadata, :text)
  end
end
