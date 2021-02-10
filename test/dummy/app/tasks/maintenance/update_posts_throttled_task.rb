# frozen_string_literal: true
module Maintenance
  class UpdatePostsThrottledTask < MaintenanceTasks::Task
    class << self
      attr_accessor :throttle
    end

    throttle_on -> { throttle }

    def collection
      Post.where(id: 1)
    end

    def count
      collection.count
    end

    def process(post)
      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
