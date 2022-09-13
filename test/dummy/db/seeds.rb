# frozen_string_literal: true

10.times do |i|
  Post.create!(title: "Post ##{i}", content: "Content ##{i}")
end

module MaintenanceTasks
  10.times do
    Run.create!(
      task_name: "Maintenance::UpdatePostsTask",
      started_at: Time.now,
      tick_count: 10,
      tick_total: 10,
      status: :succeeded,
      ended_at: Time.now,
    )
  end
end
