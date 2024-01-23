# frozen_string_literal: true

module Maintenance
  class ErrorTask < MaintenanceTasks::Task
    def collection
      [1, 2, 3, 4, 5]
    end

    def process(input)
      raise ArgumentError, "Something went wrong" if input == 3
    end
  end
end
