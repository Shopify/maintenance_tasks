# frozen_string_literal: true

module Maintenance
  class NoCollectionTask < MaintenanceTasks::Task
    no_collection

    def process
      Rails.logger.debug("#process method was called")
    end
  end
end
