# frozen_string_literal: true

class NotAutoloadedTask < MaintenanceTasks::Task
  def collection
    [1, 2]
  end

  def process(_); end
end
