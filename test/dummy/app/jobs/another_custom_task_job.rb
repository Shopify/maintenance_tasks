# frozen_string_literal: true

class AnotherCustomTaskJob < MaintenanceTasks::TaskJob
  queue_as :custom_queue
end
