# frozen_string_literal: true
module Maintenance
  class ParamsTask < MaintenanceTasks::Task
    attribute :post_ids, IntegerArrayType.new
    validates :post_ids, presence: true

    class << self
      attr_accessor :fast_task
    end

    def collection
      Post.where(id: post_ids)
    end

    def count
      collection.count
    end

    def process(post)
      sleep(1) unless self.class.fast_task

      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
