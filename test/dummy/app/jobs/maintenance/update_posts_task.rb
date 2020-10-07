# frozen_string_literal: true
module Maintenance
  class UpdatePostsTask < MaintenanceTasks::Task
    def build_enumerator(_, cursor:)
      enumerator_builder.active_record_on_records(
        Post.all,
        cursor: cursor,
      )
    end

    def each_iteration(post, _)
      sleep(Rails.env.test? ? 0 : 1)

      post.update!(content: "New content added on #{Time.now.utc}")
    end
  end
end
