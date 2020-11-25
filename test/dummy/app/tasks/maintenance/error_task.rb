# frozen_string_literal: true
module Maintenance
  class ErrorTask < MaintenanceTasks::Task
    def collection
      [1, 2]
    end

    def process(input)
      raise ArgumentError, 'Something went wrong' if input == 2
    end
  end
end
