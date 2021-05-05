# frozen_string_literal: true
module Maintenance
  class UpdatePostsInBatchesTask < MaintenanceTasks::Task
    in_batches 5

    def collection
      Post.all
    end

    def count
      collection.count
    end

    def process(batch_of_posts)
      Post.where(id: batch_of_posts.map(&:id)).update_all(
        content: "New content added on #{Time.now.utc}"
      )
    end
  end
end
