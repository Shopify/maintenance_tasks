# frozen_string_literal: true

module Maintenance
  # Any job enqueued for this task gets cancelled, see CustomTaskJob.
  class CancelledEnqueueTask < MaintenanceTasks::Task
    self.archived = true
    def collection
      []
    end
  end
end
