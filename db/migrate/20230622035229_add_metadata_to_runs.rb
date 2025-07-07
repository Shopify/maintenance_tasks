# frozen_string_literal: true

class AddMetadataToRuns < ActiveRecord::Migration[7.0]
  def change
    add_column(:maintenance_tasks_runs, :metadata, :text)
  end
end
