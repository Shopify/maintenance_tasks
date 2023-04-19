# frozen_string_literal: true

module Maintenance
  module Nested
    module NestedMore
      class NestedMoreTask < MaintenanceTasks::Task
        def process(rows)
          # Task only exists to verify correct loading of tasks within subfolders
        end
      end
    end
  end
end
