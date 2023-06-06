# frozen_string_literal: true

require "test_module"

module Maintenance
  class UpdatePostsModulePrependedTask < MaintenanceTasks::Task
    prepend TestModule

    class << self
      attr_accessor :fast_task
    end

    def collection
      Post.all
    end

    def process(post)
      sleep(1) unless self.class.fast_task

      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
