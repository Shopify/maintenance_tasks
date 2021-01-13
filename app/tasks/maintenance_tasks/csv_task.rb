# frozen_string_literal: true

require 'csv'

module MaintenanceTasks
  # Base class that is inherited by the host application's task classes.
  class CsvTask < Task
    def initialize(csv_file)
      super()
      @csv_file = csv_file
    end

    def collection
      CSV.new(@csv_file.download, headers: true, converters: :integer)
    end

    def self.csv_task?
      true
    end
  end
end
