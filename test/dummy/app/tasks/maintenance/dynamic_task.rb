# frozen_string_literal: true

module Maintenance
  class DynamicTask < MaintenanceTasks::Task
    def collection
      ->(cursor:) { [1, 2, 3].lazy.with_index.drop(cursor || 0) }
    end

    def count
      3
    end

    def process(number)
      Rails.logger.debug("number: #{number}")
    end
  end
end
