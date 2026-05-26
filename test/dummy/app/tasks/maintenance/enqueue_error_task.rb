# frozen_string_literal: true

module Maintenance
  # Any job enqueued for this task errors, see CustomTaskJob.
  class EnqueueErrorTask < MaintenanceTasks::Task
    tag :errors

    def collection
      []
    end
  end
end
