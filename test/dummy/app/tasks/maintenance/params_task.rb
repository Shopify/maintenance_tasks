# frozen_string_literal: true

module Maintenance
  class ParamsTask < MaintenanceTasks::Task
    attribute :post_ids, :string

    validates :post_ids,
      presence: true,
      format: { with: /\A(\s?\d+(,\s?\d+\s?)*)\z/, allow_blank: true }

    attribute :content, :string, default: "default content"
    attribute :integer_attr, :integer, default: 111_222_333
    attribute :big_integer_attr, :big_integer, default: 111_222_333
    attribute :float_attr, :float, default: 12.34
    attribute :decimal_attr, :decimal, default: 12.34
    attribute :datetime_attr, :datetime
    attribute :date_attr, :date
    attribute :time_attr, :time
    attribute :boolean_attr, :boolean

    class << self
      attr_accessor :fast_task
    end

    def collection
      Post.where(id: post_ids_array)
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
