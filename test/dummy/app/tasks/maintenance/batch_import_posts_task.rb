# frozen_string_literal: true

module Maintenance
  class BatchImportPostsTask < MaintenanceTasks::Task
    csv_collection(in_batches: 2)

    def process(post_rows)
      Post.insert_all(post_rows.map(&:to_h))
    end
  end
end
