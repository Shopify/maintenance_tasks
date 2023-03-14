# frozen_string_literal: true

module Maintenance
  class AbstractTask < MaintenanceTasks::Task
    def initialize
      raise NotImplementedError
    end
  end
end
