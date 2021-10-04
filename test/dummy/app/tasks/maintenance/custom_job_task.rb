# frozen_string_literal: true
module Maintenance
  class CustomJobTask < MaintenanceTasks::Task
    with_job_class "CustomTaskJob"

    def collection
      [1, 2]
    end

    def count
      collection.count
    end

    def process(number)
      Rails.logger.debug("number: #{number}")
    end
  end
end
