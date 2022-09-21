# frozen_string_literal: true

module Maintenance
  class TestTask < MaintenanceTasks::Task
    def collection
      [1, 2]
    end

    def process(number)
      Rails.logger.debug("number: #{number}")
    end
  end
end
