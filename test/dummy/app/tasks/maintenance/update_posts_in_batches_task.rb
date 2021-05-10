# frozen_string_literal: true
module Maintenance
  class UpdatePostsInBatchesTask < MaintenanceTasks::Task
    def collection
      Post.in_batches(of: 5)
    end

    def count
      Post.count
    end

    def process(batch_of_posts)
      batch_of_posts.update_all(content: "New content added on #{Time.now.utc}")
    end
  end
end
