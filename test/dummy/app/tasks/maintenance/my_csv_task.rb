# frozen_string_literal: true
module Maintenance
  class MyCsvTask < MaintenanceTasks::CsvTask
    def count
      collection.count
    end

    def process(element)
      puts element
      sleep(1)
    end
  end
end
