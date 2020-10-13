# frozen_string_literal: true
module Maintenance
  class ErrorTask < MaintenanceTasks::Task
    def task_enumerator(*)
      [1, 2].to_enum
    end

    def task_iteration(*)
      raise ArgumentError, 'Something went wrong'
    end
  end
end
