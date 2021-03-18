# frozen_string_literal: true

class CustomTaskJob < MaintenanceTasks::TaskJob
  before_enqueue do |job|
    run = job.arguments.first
    raise "Error enqueuing" if run.task_name == "Maintenance::EnqueueErrorTask"
    throw :abort if run.task_name == "Maintenance::CancelledEnqueueTask"
  end
end
