# frozen_string_literal: true

module Maintenance
  class ImportPostsWithEncodingTask < MaintenanceTasks::Task
    csv_collection(encoding: Encoding::ASCII)

    def process(row)
      Post.create!(title: row["title"], content: row[" content"])
    end
  end
end
