# frozen_string_literal: true
10.times do |i|
  Post.create!(title: "Post ##{i}", content: "Content ##{i}")
end

module MaintenanceTasks
  time = Time.now
  9.times do |id|
    Run.create!(
      id: 10 - id,
      task_name: 'Maintenance::UpdatePostsTask',
      created_at: time,
      started_at: time + rand(1.minute),
      tick_count: 10,
      tick_total: 10,
      status: :succeeded,
      ended_at: time + rand(10.minutes),
    )
    time -= rand(7.days)
  end
  Run.new(
    id: 1,
    task_name: 'Maintenance::DeletedTask',
    created_at: time,
    started_at: time + rand(10.seconds),
    tick_count: 42,
    tick_total: 42,
    status: :errored,
    ended_at: time + rand(10.minutes),
  ).save(validate: false)
end
