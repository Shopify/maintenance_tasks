# frozen_string_literal: true
module Maintenance
  class TestCsvTask < MaintenanceTasks::Task
    include MaintenanceTasks::CsvTask

    def process(csv_row)
      Rails.logger.debug("CSV Row:\n #{csv_row}")
    end
  end
end
