# frozen_string_literal: true

class IgnoredTask < MaintenanceTasks::Task
  def collection
    []
  end

  def process(_element)
  end
end
