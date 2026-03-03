# frozen_string_literal: true

module Maintenance
  class OutdatedTask < MaintenanceTasks::Task
    def collection
      [1, 2]
    end

    def process(number)
      Rails.logger.debug("This task is outdated")
    end
  end
end
