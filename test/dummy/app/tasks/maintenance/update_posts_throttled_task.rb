# frozen_string_literal: true

module Maintenance
  class UpdatePostsThrottledTask < MaintenanceTasks::Task
    class << self
      attr_accessor :throttle, :throttle_proc
    end

    throttle_on { throttle }
    throttle_on(backoff: -> { 10.seconds }) { throttle_proc }

    def collection
      Post.all
    end

    def count
      collection.count
    end

    def process(post)
      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
