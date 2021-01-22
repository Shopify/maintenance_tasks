# frozen_string_literal: true

module Maintenance
  # TODO: Rename this & update tests
  class DynamicTask < MaintenanceTasks::Task
    def enumerator(context:)
      [1, 2, 3].lazy.with_index.drop(context.cursor || 0)
    end

    def count
      3
    end

    def process(number)
      Rails.logger.debug("number: #{number}")
    end
  end
end
