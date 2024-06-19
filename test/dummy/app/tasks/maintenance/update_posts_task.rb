# frozen_string_literal: true

module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    class << self
      attr_accessor :fast_task
    end

    collection_batch_size 1000

    def collection
      Post.all
    end

    def process(post)
      sleep(1) unless self.class.fast_task

      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
