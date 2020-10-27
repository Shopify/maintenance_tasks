# frozen_string_literal: true
10.times do |i|
  Post.create!(title: "Post ##{i}", content: "Content ##{i}")
end

module MaintenanceTasks
  10.times do
    Run.create!(
      task_name: 'Maintenance::UpdatePostsTask',
      tick_count: 10,
      tick_total: 10,
      status: :succeeded
    )
  end
end
