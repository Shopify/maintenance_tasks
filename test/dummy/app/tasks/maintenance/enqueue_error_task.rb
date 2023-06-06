# frozen_string_literal: true

module Maintenance
  # Any job enqueued for this task errors, see CustomTaskJob.
  class EnqueueErrorTask < MaintenanceTasks::Task
    self.archived = true
    def collection
      []
    end
  end
end
