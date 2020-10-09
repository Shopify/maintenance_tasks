# frozen_string_literal: true
module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    class << self
      attr_accessor :fast_task
    end

    def task_enumerator(cursor:)
      enumerator_builder.active_record_on_records(
        Post.all,
        cursor: cursor,
      )
    end

    def task_iteration(post)
      sleep(1) unless self.class.fast_task

      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
