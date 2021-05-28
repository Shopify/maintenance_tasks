# frozen_string_literal: true
module Maintenance
  class ParamsTask < MaintenanceTasks::Task
    attribute :post_ids, :string

    validates :post_ids,
      presence: true,
      format: { with: /\A(\s?\d+(,\s?\d+\s?)*)\z/, allow_blank: true }

    class << self
      attr_accessor :fast_task
    end

    def collection
      Post.where(id: post_ids_array)
    end

    def count
      collection.count
    end

    def process(post)
      sleep(1) unless self.class.fast_task

      post.update!(content: "New content added on #{Time.now.utc}")
    end

    private

    def post_ids_array
      post_ids.split(",")
    end
  end
end
