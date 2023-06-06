# frozen_string_literal: true

module Maintenance
  class ArchivedTask < MaintenanceTasks::Task
    self.archived = true

    no_collection

    def process
      Rails.logger.debug("I am archived and cannot be run")
    end
  end
end
