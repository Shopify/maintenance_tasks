# frozen_string_literal: true

module Maintenance
  class OutputTask < MaintenanceTasks::Task
    no_collection

    def process
      # do nothing...
    end

    def output
      "Some task output"
    end
  end
end
