# frozen_string_literal: true

module Maintenance
  class StaleTask < MaintenanceTasks::Task
    def collection
      [1, 2]
    end

    def process(number)
      Rails.logger.debug("This task is stale")
    end
  end
end
