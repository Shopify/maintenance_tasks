# frozen_string_literal: true

module Maintenance
  module Nested
    module NestedMore
      class NestedMoreTask < MaintenanceTasks::Task
        no_collection

        def process
          # Task only exists to verify correct loading of tasks within subfolders
        end
      end
    end
  end
end
