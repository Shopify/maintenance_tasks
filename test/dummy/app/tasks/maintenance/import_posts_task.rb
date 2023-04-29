# frozen_string_literal: true

module Maintenance
  class ImportPostsTask < MaintenanceTasks::Task
    self.tags = [:data_maintenance]

    csv_collection

    def process(row)
      Post.create!(title: row["title"], content: row["content"])
    end
  end
end
