# frozen_string_literal: true
module Maintenance
  class ParamsTask < MaintenanceTasks::Task
    param :title, String

    def collection
      Post.where(title: title)
    end

    def count
      collection.count
    end

    def process(post)
      sleep(1)

      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
