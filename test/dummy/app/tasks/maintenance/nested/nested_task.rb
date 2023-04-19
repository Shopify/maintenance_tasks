# frozen_string_literal: true

module Maintenance
  module Nested
    class NestedTask < MaintenanceTasks::Task
      no_collection

      def process
        # Task only exists to verify correct loading of tasks within subfolders
      end
    end
  end
end
