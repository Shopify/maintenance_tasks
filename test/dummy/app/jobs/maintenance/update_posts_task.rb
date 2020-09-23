# frozen_string_literal: true
module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    def build_enumerator(cursor:)
      enumerator_builder.active_record_on_records(
        Post.all,
        cursor: cursor,
      )
    end

    def each_iteration(post)
      sleep(3)

      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
