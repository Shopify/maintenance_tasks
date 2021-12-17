# frozen_string_literal: true

class CustomTaskJob < MaintenanceTasks::TaskJob
  before_enqueue do |job|
    run = job.arguments.first
    raise "Error enqueuing" if run.task_name == "Maintenance::EnqueueErrorTask"
    throw :abort if run.task_name == "Maintenance::CancelledEnqueueTask"
  end

  class_attribute :race_condition_hook, instance_accessor: false
  class_attribute :race_condition_after_hook, instance_accessor: false

  before_perform(prepend: true) do
    CustomTaskJob.race_condition_hook&.call
  end

  after_perform do
    CustomTaskJob.race_condition_after_hook&.call
  end
end
