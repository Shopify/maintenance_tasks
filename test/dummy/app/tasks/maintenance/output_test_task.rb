# frozen_string_literal: true

module Maintenance
  class OutputTestTask < MaintenanceTasks::Task
    def collection
      (1..5).to_a
    end

    def process(element)
      log_output("Processing element #{element}")
      log_output("Square of #{element} is #{element * element}")
    end
  end
end
