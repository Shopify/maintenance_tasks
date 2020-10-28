# frozen_string_literal: true
module Maintenance
  class ErrorTask < MaintenanceTasks::Task
    def collection
      [1, 2]
    end

    def process(*)
      raise ArgumentError, 'Something went wrong'
    end
  end
end
