# frozen_string_literal: true

module Maintenance
  class CompositePrimaryKeyModelTask < MaintenanceTasks::Task
    def collection
      Order.all
    end

    def process(order)
      order.update!(name: "Order ##{order.number}")
    end
  end
end
